#!/usr/bin/env python3
"""Generate Horos.xcodeproj without XcodeGen.

Walks the source folders, mirrors them as Xcode groups and writes a complete
project.pbxproj plus a shared scheme. Deterministic IDs so re-running produces
no spurious diffs. Run from anywhere:  python3 Scripts/generate_xcodeproj.py
"""
import hashlib
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROJECT_NAME = "Horos"
DEPLOYMENT_TARGET = "17.0"
SWIFT_VERSION = "5.0"

APP_TARGET = "Horos"
EXTENSIONS = [
    # name, bundle id suffix
    ("DeviceActivityMonitorExtension", "monitor"),
    ("ShieldConfigurationExtension", "shieldconfiguration"),
    ("ShieldActionExtension", "shieldaction"),
    ("DeviceActivityReportExtension", "report"),
]
SHARED_DIR = "SharedCore"

# ───────────────────────────── helpers ─────────────────────────────

def uid(*parts):
    """24-hex-char deterministic identifier."""
    return hashlib.sha1("|".join(parts).encode()).hexdigest()[:24].upper()

_UNQUOTED = re.compile(r"^[A-Za-z0-9_./]+$")

def q(value):
    value = str(value)
    if _UNQUOTED.match(value):
        return value
    escaped = value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return f'"{escaped}"'

def settings_block(settings, indent="\t\t\t\t"):
    lines = []
    for key in sorted(settings):
        value = settings[key]
        if isinstance(value, (list, tuple)):
            inner = "".join(f"{indent}\t{q(v)},\n" for v in value)
            lines.append(f"{indent}{key} = (\n{inner}{indent});\n")
        else:
            lines.append(f"{indent}{key} = {q(value)};\n")
    return "".join(lines)

FILE_TYPES = {
    ".swift": "sourcecode.swift",
    ".plist": "text.plist.xml",
    ".entitlements": "text.plist.entitlements",
    ".xcassets": "folder.assetcatalog",
    ".md": "net.daringfireball.markdown",
    ".sh": "text.script.sh",
    ".py": "text.script.python",
    ".yml": "text.yaml",
}

objects = {}          # id -> (isa, body-string, comment)

def add(obj_id, isa, body, comment):
    objects[obj_id] = (isa, body, comment)
    return obj_id

# ───────────────────────────── file tree ─────────────────────────────

file_refs = {}        # relative path -> id

def file_ref(rel_path):
    rel_path = str(rel_path)
    if rel_path in file_refs:
        return file_refs[rel_path]
    name = os.path.basename(rel_path)
    ext = os.path.splitext(name)[1]
    ftype = FILE_TYPES.get(ext, "text")
    fid = uid("fileref", rel_path)
    add(fid, "PBXFileReference",
        f"isa = PBXFileReference; lastKnownFileType = {ftype}; path = {q(name)}; sourceTree = \"<group>\"; ",
        name)
    file_refs[rel_path] = fid
    return fid

def build_group(rel_dir, name=None):
    """Recursively mirror a directory as PBXGroups; returns group id."""
    abs_dir = ROOT / rel_dir
    children = []
    for entry in sorted(abs_dir.iterdir(), key=lambda p: (p.is_file(), p.name.lower())):
        if entry.name.startswith(".") or entry.name in ("build.log", "Horos.xcodeproj"):
            continue
        rel = f"{rel_dir}/{entry.name}" if rel_dir else entry.name
        if entry.is_dir() and entry.suffix != ".xcassets":
            children.append(build_group(rel))
        else:
            children.append(file_ref(rel))
    gid = uid("group", rel_dir)
    base = os.path.basename(rel_dir)
    kids = "".join(f"\t\t\t\t{c} /* {objects[c][2]} */,\n" for c in children)
    add(gid, "PBXGroup",
        f"isa = PBXGroup;\n\t\t\tchildren = (\n{kids}\t\t\t);\n\t\t\tpath = {q(base)};\n\t\t\tsourceTree = \"<group>\";\n\t\t",
        name or base)
    return gid

def swift_files(rel_dir):
    out = []
    for path in sorted((ROOT / rel_dir).rglob("*.swift")):
        out.append(str(path.relative_to(ROOT)))
    return out

# ───────────────────────────── groups ─────────────────────────────

top_groups = [build_group(APP_TARGET), build_group(SHARED_DIR)]
for name, _ in EXTENSIONS:
    top_groups.append(build_group(name))
top_groups.append(build_group("Scripts"))
for extra in ("project.yml", "README.md"):
    if (ROOT / extra).exists():
        top_groups.append(file_ref(extra))

# Products group
product_refs = {}
def product_ref(target, is_app):
    pid = uid("product", target)
    if is_app:
        body = f"isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {target}.app; sourceTree = BUILT_PRODUCTS_DIR; "
        comment = f"{target}.app"
    else:
        body = f"isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = {target}.appex; sourceTree = BUILT_PRODUCTS_DIR; "
        comment = f"{target}.appex"
    add(pid, "PBXFileReference", body, comment)
    product_refs[target] = pid
    return pid

all_targets = [APP_TARGET] + [n for n, _ in EXTENSIONS]
for t in all_targets:
    product_ref(t, t == APP_TARGET)

products_group = uid("group", "Products")
kids = "".join(f"\t\t\t\t{product_refs[t]} /* {objects[product_refs[t]][2]} */,\n" for t in all_targets)
add(products_group, "PBXGroup",
    f"isa = PBXGroup;\n\t\t\tchildren = (\n{kids}\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = \"<group>\";\n\t\t",
    "Products")

main_group = uid("group", "<main>")
kids = "".join(f"\t\t\t\t{g} /* {objects[g][2]} */,\n" for g in top_groups + [products_group])
add(main_group, "PBXGroup",
    f"isa = PBXGroup;\n\t\t\tchildren = (\n{kids}\t\t\t);\n\t\t\tsourceTree = \"<group>\";\n\t\t",
    None)

# ───────────────────────────── build configurations ─────────────────────────────

PROJECT_COMMON = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
    "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_ENABLE_OBJC_WEAK": "YES",
    "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
    "CLANG_WARN_BOOL_CONVERSION": "YES",
    "CLANG_WARN_COMMA": "YES",
    "CLANG_WARN_CONSTANT_CONVERSION": "YES",
    "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
    "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
    "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
    "CLANG_WARN_EMPTY_BODY": "YES",
    "CLANG_WARN_ENUM_CONVERSION": "YES",
    "CLANG_WARN_INFINITE_RECURSION": "YES",
    "CLANG_WARN_INT_CONVERSION": "YES",
    "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES",
    "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
    "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
    "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES",
    "CLANG_WARN_STRICT_PROTOTYPES": "YES",
    "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
    "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
    "CLANG_WARN_UNREACHABLE_CODE": "YES",
    "CLANG_WARN__DUPLICATE_METHOD_MATCH": "YES",
    "COPY_PHASE_STRIP": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
    "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
    "GCC_WARN_UNDECLARED_SELECTOR": "YES",
    "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
    "GCC_WARN_UNUSED_FUNCTION": "YES",
    "GCC_WARN_UNUSED_VARIABLE": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
    "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
    "MTL_FAST_MATH": "YES",
    "SDKROOT": "iphoneos",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "SWIFT_VERSION": SWIFT_VERSION,
    "TARGETED_DEVICE_FAMILY": "1,2",
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": "",
    "CURRENT_PROJECT_VERSION": "1",
    "MARKETING_VERSION": "1.0.0",
    "GENERATE_INFOPLIST_FILE": "NO",
}
PROJECT_DEBUG = {
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_TESTABILITY": "YES",
    "GCC_DYNAMIC_NO_PIC": "NO",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)",
    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
}
PROJECT_RELEASE = {
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    "ENABLE_NS_ASSERTIONS": "NO",
    "MTL_ENABLE_DEBUG_INFO": "NO",
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "SWIFT_OPTIMIZATION_LEVEL": "-O",
    "VALIDATE_PRODUCT": "YES",
}

def target_settings(target):
    if target == APP_TARGET:
        return {
            "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
            "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
            "CODE_SIGN_ENTITLEMENTS": "Horos/Resources/Horos.entitlements",
            "ENABLE_PREVIEWS": "YES",
            "INFOPLIST_FILE": "Horos/Resources/Info.plist",
            "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
            "PRODUCT_BUNDLE_IDENTIFIER": "com.horos.app",
            "PRODUCT_NAME": "$(TARGET_NAME)",
        }
    suffix = dict(EXTENSIONS)[target]
    return {
        "APPLICATION_EXTENSION_API_ONLY": "YES",
        "CODE_SIGN_ENTITLEMENTS": f"{target}/{target}.entitlements",
        "INFOPLIST_FILE": f"{target}/Info.plist",
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"],
        "PRODUCT_BUNDLE_IDENTIFIER": f"com.horos.app.{suffix}",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SKIP_INSTALL": "YES",
    }

def config(obj_id, name, settings):
    add(obj_id, "XCBuildConfiguration",
        f"isa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n{settings_block(settings)}\t\t\t}};\n\t\t\tname = {name};\n\t\t",
        name)
    return obj_id

def config_list(obj_id, debug_id, release_id, comment):
    add(obj_id, "XCConfigurationList",
        "isa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n"
        f"\t\t\t\t{debug_id} /* Debug */,\n\t\t\t\t{release_id} /* Release */,\n\t\t\t);\n"
        "\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t",
        comment)
    return obj_id

project_debug = config(uid("cfg", "project", "Debug"), "Debug", {**PROJECT_COMMON, **PROJECT_DEBUG})
project_release = config(uid("cfg", "project", "Release"), "Release", {**PROJECT_COMMON, **PROJECT_RELEASE})
project_cfg_list = config_list(uid("cfglist", "project"), project_debug, project_release,
                               f'Build configuration list for PBXProject "{PROJECT_NAME}"')

# ───────────────────────────── targets ─────────────────────────────

project_id = uid("project")
target_ids = {}
target_sections = []

def build_file(target, rel_path, comment_suffix, settings=None):
    bid = uid("buildfile", target, rel_path)
    ref = file_refs[rel_path] if rel_path in file_refs else rel_path  # product refs pass raw ids
    extra = f" settings = {{{settings}}};" if settings else ""
    add(bid, "PBXBuildFile", f"isa = PBXBuildFile; fileRef = {ref} /* {comment_suffix} */;{extra} ",
        f"{comment_suffix} in {'Embed Foundation Extensions' if settings else ('Resources' if rel_path.endswith('.xcassets') else 'Sources')}")
    return bid

def phase(obj_id, isa, name, files, extra=""):
    kids = "".join(f"\t\t\t\t{f} /* {objects[f][2]} */,\n" for f in files)
    body = (f"isa = {isa};\n\t\t\tbuildActionMask = 2147483647;\n{extra}"
            f"\t\t\tfiles = (\n{kids}\t\t\t);\n")
    if name:
        body += f"\t\t\tname = {q(name)};\n"
    body += "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t"
    add(obj_id, isa, body, name or isa.replace("PBX", "").replace("BuildPhase", ""))
    return obj_id

shared_sources = swift_files(SHARED_DIR)

for target in all_targets:
    is_app = target == APP_TARGET
    tid = uid("target", target)
    target_ids[target] = tid

    sources = swift_files(target) + shared_sources
    source_files = [build_file(target, s, os.path.basename(s)) for s in sources]
    sources_phase = phase(uid("phase", "sources", target), "PBXSourcesBuildPhase", None, source_files)
    frameworks_phase = phase(uid("phase", "frameworks", target), "PBXFrameworksBuildPhase", None, [])

    resources = []
    if is_app:
        resources.append(build_file(target, "Horos/Resources/Assets.xcassets", "Assets.xcassets"))
    resources_phase = phase(uid("phase", "resources", target), "PBXResourcesBuildPhase", None, resources)

    phases = [sources_phase, frameworks_phase, resources_phase]
    dependencies = []
    if is_app:
        embed_files = []
        for ext_name, _ in EXTENSIONS:
            bid = uid("buildfile", target, "embed", ext_name)
            add(bid, "PBXBuildFile",
                f"isa = PBXBuildFile; fileRef = {product_refs[ext_name]} /* {ext_name}.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; ",
                f"{ext_name}.appex in Embed Foundation Extensions")
            embed_files.append(bid)
            proxy = uid("proxy", ext_name)
            add(proxy, "PBXContainerItemProxy",
                f"isa = PBXContainerItemProxy;\n\t\t\tcontainerPortal = {project_id} /* Project object */;\n\t\t\tproxyType = 1;\n"
                f"\t\t\tremoteGlobalIDString = {uid('target', ext_name)};\n\t\t\tremoteInfo = {ext_name};\n\t\t",
                "PBXContainerItemProxy")
            dep = uid("dependency", ext_name)
            add(dep, "PBXTargetDependency",
                f"isa = PBXTargetDependency;\n\t\t\ttarget = {uid('target', ext_name)} /* {ext_name} */;\n\t\t\ttargetProxy = {proxy} /* PBXContainerItemProxy */;\n\t\t",
                "PBXTargetDependency")
            dependencies.append(dep)
        embed_phase = phase(uid("phase", "embed", target), "PBXCopyFilesBuildPhase", "Embed Foundation Extensions",
                            embed_files, extra="\t\t\tdstPath = \"\";\n\t\t\tdstSubfolderSpec = 13;\n")
        phases.append(embed_phase)

    dbg = config(uid("cfg", target, "Debug"), "Debug", target_settings(target))
    rel = config(uid("cfg", target, "Release"), "Release", target_settings(target))
    cfg_list = config_list(uid("cfglist", target), dbg, rel, f'Build configuration list for PBXNativeTarget "{target}"')

    phases_str = "".join(f"\t\t\t\t{p} /* {objects[p][2]} */,\n" for p in phases)
    deps_str = "".join(f"\t\t\t\t{d} /* PBXTargetDependency */,\n" for d in dependencies)
    product_type = "com.apple.product-type.application" if is_app else "com.apple.product-type.app-extension"
    add(tid, "PBXNativeTarget",
        f"isa = PBXNativeTarget;\n\t\t\tbuildConfigurationList = {cfg_list} /* Build configuration list for PBXNativeTarget \"{target}\" */;\n"
        f"\t\t\tbuildPhases = (\n{phases_str}\t\t\t);\n\t\t\tbuildRules = (\n\t\t\t);\n"
        f"\t\t\tdependencies = (\n{deps_str}\t\t\t);\n\t\t\tname = {target};\n\t\t\tproductName = {target};\n"
        f"\t\t\tproductReference = {product_refs[target]} /* {objects[product_refs[target]][2]} */;\n"
        f"\t\t\tproductType = \"{product_type}\";\n\t\t",
        target)

# ───────────────────────────── project object ─────────────────────────────

target_attrs = "".join(f"\t\t\t\t\t{target_ids[t]} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.2;\n\t\t\t\t\t}};\n" for t in all_targets)
targets_str = "".join(f"\t\t\t\t{target_ids[t]} /* {t} */,\n" for t in all_targets)
add(project_id, "PBXProject",
    "isa = PBXProject;\n\t\t\tattributes = {\n\t\t\t\tBuildIndependentTargetsInParallel = 1;\n"
    "\t\t\t\tLastSwiftUpdateCheck = 1520;\n\t\t\t\tLastUpgradeCheck = 1520;\n"
    f"\t\t\t\tTargetAttributes = {{\n{target_attrs}\t\t\t\t}};\n\t\t\t}};\n"
    f"\t\t\tbuildConfigurationList = {project_cfg_list} /* Build configuration list for PBXProject \"{PROJECT_NAME}\" */;\n"
    "\t\t\tcompatibilityVersion = \"Xcode 14.0\";\n\t\t\tdevelopmentRegion = en;\n\t\t\thasScannedForEncodings = 0;\n"
    "\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t);\n"
    f"\t\t\tmainGroup = {main_group};\n\t\t\tproductRefGroup = {products_group} /* Products */;\n"
    "\t\t\tprojectDirPath = \"\";\n\t\t\tprojectRoot = \"\";\n"
    f"\t\t\ttargets = (\n{targets_str}\t\t\t);\n\t\t",
    "Project object")

# ───────────────────────────── emit ─────────────────────────────

SECTION_ORDER = ["PBXBuildFile", "PBXContainerItemProxy", "PBXCopyFilesBuildPhase", "PBXFileReference",
                 "PBXFrameworksBuildPhase", "PBXGroup", "PBXNativeTarget", "PBXProject", "PBXResourcesBuildPhase",
                 "PBXSourcesBuildPhase", "PBXTargetDependency", "XCBuildConfiguration", "XCConfigurationList"]

out = ["// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 56;\n\tobjects = {\n"]
for isa in SECTION_ORDER:
    entries = sorted((k, v) for k, v in objects.items() if v[0] == isa)
    if not entries:
        continue
    out.append(f"\n/* Begin {isa} section */\n")
    for obj_id, (_, body, comment) in entries:
        label = f" /* {comment} */" if comment else ""
        if "\n" in body:
            out.append(f"\t\t{obj_id}{label} = {{\n\t\t\t{body}}};\n")
        else:
            out.append(f"\t\t{obj_id}{label} = {{{body}}};\n")
    out.append(f"/* End {isa} section */\n")
out.append(f"\t}};\n\trootObject = {project_id} /* Project object */;\n}}\n")

proj_dir = ROOT / f"{PROJECT_NAME}.xcodeproj"
proj_dir.mkdir(exist_ok=True)
(proj_dir / "project.pbxproj").write_text("".join(out))

# workspace + shared scheme so `xcodebuild -scheme Horos` works out of the box
ws = proj_dir / "project.xcworkspace"
ws.mkdir(exist_ok=True)
(ws / "contents.xcworkspacedata").write_text(
    '<?xml version="1.0" encoding="UTF-8"?>\n<Workspace\n   version = "1.0">\n'
    '   <FileRef\n      location = "self:">\n   </FileRef>\n</Workspace>\n')
(ws / "xcshareddata").mkdir(exist_ok=True)
(ws / "xcshareddata" / "IDEWorkspaceChecks.plist").write_text(
    '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
    '<plist version="1.0">\n<dict>\n\t<key>IDEDidComputeMac32BitWarning</key>\n\t<true/>\n</dict>\n</plist>\n')

schemes = proj_dir / "xcshareddata" / "xcschemes"
schemes.mkdir(parents=True, exist_ok=True)
app_tid = target_ids[APP_TARGET]
def buildable(tid, name, product):
    return (f'            <BuildableReference\n               BuildableIdentifier = "primary"\n               BlueprintIdentifier = "{tid}"\n'
            f'               BuildableName = "{product}"\n               BlueprintName = "{name}"\n'
            f'               ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">\n            </BuildableReference>\n')
build_entries = "".join(
    f'         <BuildActionEntry\n            buildForTesting = "YES"\n            buildForRunning = "YES"\n            buildForProfiling = "YES"\n'
    f'            buildForArchiving = "YES"\n            buildForAnalyzing = "YES">\n'
    + buildable(target_ids[t], t, f"{t}.app" if t == APP_TARGET else f"{t}.appex")
    + '         </BuildActionEntry>\n'
    for t in all_targets)
(schemes / f"{PROJECT_NAME}.xcscheme").write_text(
    '<?xml version="1.0" encoding="UTF-8"?>\n<Scheme\n   LastUpgradeVersion = "1520"\n   version = "1.7">\n'
    '   <BuildAction\n      parallelizeBuildables = "YES"\n      buildImplicitDependencies = "YES">\n      <BuildActionEntries>\n'
    + build_entries +
    '      </BuildActionEntries>\n   </BuildAction>\n'
    '   <TestAction\n      buildConfiguration = "Debug"\n      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"\n'
    '      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"\n      shouldUseLaunchSchemeArgsEnv = "YES">\n'
    '      <Testables>\n      </Testables>\n   </TestAction>\n'
    '   <LaunchAction\n      buildConfiguration = "Debug"\n      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"\n'
    '      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"\n      launchStyle = "0"\n      useCustomWorkingDirectory = "NO"\n'
    '      ignoresPersistentStateOnLaunch = "NO"\n      debugDocumentVersioning = "YES"\n      debugServiceExtension = "internal"\n'
    '      allowLocationSimulation = "YES">\n      <BuildableProductRunnable\n         runnableDebuggingMode = "0">\n'
    + buildable(app_tid, APP_TARGET, f"{APP_TARGET}.app") +
    '      </BuildableProductRunnable>\n   </LaunchAction>\n'
    '   <ProfileAction\n      buildConfiguration = "Release"\n      shouldUseLaunchSchemeArgsEnv = "YES"\n      savedToolIdentifier = ""\n'
    '      useCustomWorkingDirectory = "NO"\n      debugDocumentVersioning = "YES">\n      <BuildableProductRunnable\n         runnableDebuggingMode = "0">\n'
    + buildable(app_tid, APP_TARGET, f"{APP_TARGET}.app") +
    '      </BuildableProductRunnable>\n   </ProfileAction>\n'
    '   <AnalyzeAction\n      buildConfiguration = "Debug">\n   </AnalyzeAction>\n'
    '   <ArchiveAction\n      buildConfiguration = "Release"\n      revealArchiveInOrganizer = "YES">\n   </ArchiveAction>\n</Scheme>\n')

print(f"Wrote {proj_dir / 'project.pbxproj'} ({len(objects)} objects, {len(shared_sources)} shared sources)")
