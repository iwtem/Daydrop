#!/usr/bin/env python3
"""Generates a clean, self-contained Xcode project (Daydrop.xcodeproj) with
Daydrop (macOS App), DaydropWidget (WidgetKit Extension), and DaydropTests."""

import hashlib
import os

ROOT = "/Users/iwtem/Projects/personal/Daydrop"
PROJ_DIR = os.path.join(ROOT, "Daydrop.xcodeproj")
SCHEME_DIR = os.path.join(PROJ_DIR, "xcshareddata", "xcschemes")


def uid(name: str) -> str:
    return hashlib.md5(name.encode("utf-8")).hexdigest()[:24].upper()


SHARED_SWIFT = [
    "Shared/CalendarEngine/SolarTermCalculator.swift",
    "Shared/CalendarEngine/LunarCalendarEngine.swift",
    "Shared/CalendarEngine/CalendarDayInfo.swift",
    "Shared/CalendarEngine/MonthGridGenerator.swift",
    "Shared/HolidayData/HolidayStore.swift",
    "Shared/Theme/DaydropTheme.swift",
    "Shared/Settings/AppPreferences.swift",
    "Shared/Localization/L10n.swift",
]

SHARED_RESOURCES = [
    "Shared/HolidayData/holidays_cn.json",
]

APP_SWIFT = [
    "Daydrop/DaydropApp.swift",
    "Daydrop/AppState.swift",
    "Daydrop/Updater/AppUpdater.swift",
    "Daydrop/Window/WindowManager.swift",
    "Daydrop/Views/CalendarGridView.swift",
    "Daydrop/Views/DayDetailBannerView.swift",
    "Daydrop/Views/MonthYearPickerPopover.swift",
    "Daydrop/Views/MenuBarPopoverView.swift",
    "Daydrop/Views/YearOverviewView.swift",
    "Daydrop/Views/ExpandedCalendarView.swift",
    "Daydrop/Views/SettingsView.swift",
]

APP_RESOURCES = [
    "Daydrop/Assets.xcassets",
]

APP_EXTRA_FILES = [
    "Daydrop/Info.plist",
    "Daydrop/Daydrop.entitlements",
]

WIDGET_SWIFT = [
    "DaydropWidget/DaydropWidgetBundle.swift",
    "DaydropWidget/DaydropTimelineProvider.swift",
    "DaydropWidget/Views/SmallCalendarWidgetView.swift",
    "DaydropWidget/Views/MediumCalendarWidgetView.swift",
    "DaydropWidget/Views/LargeCalendarWidgetView.swift",
]

WIDGET_EXTRA_FILES = [
    "DaydropWidget/Info.plist",
    "DaydropWidget/DaydropWidget.entitlements",
]

TEST_SWIFT = [
    "DaydropTests/CalendarEngineTests.swift",
]


def file_type(path: str) -> str:
    if path.endswith(".swift"):
        return "sourcecode.swift"
    if path.endswith(".json"):
        return "text.json"
    if path.endswith(".xcassets"):
        return "folder.assetcatalog"
    if path.endswith(".plist"):
        return "text.plist.xml"
    if path.endswith(".entitlements"):
        return "text.plist.entitlements"
    if path.endswith(".strings"):
        return "text.plist.strings"
    return "text"


def generate():
    os.makedirs(SCHEME_DIR, exist_ok=True)

    all_files = (
        SHARED_SWIFT
        + SHARED_RESOURCES
        + APP_SWIFT
        + APP_RESOURCES
        + APP_EXTRA_FILES
        + WIDGET_SWIFT
        + WIDGET_EXTRA_FILES
        + TEST_SWIFT
    )

    # Product references
    app_prod_id = uid("PROD:Daydrop.app")
    widget_prod_id = uid("PROD:DaydropWidget.appex")
    test_prod_id = uid("PROD:DaydropTests.xctest")

    # Targets
    app_target_id = uid("TARGET:Daydrop")
    widget_target_id = uid("TARGET:DaydropWidget")
    test_target_id = uid("TARGET:DaydropTests")

    # Build phases
    app_sources_phase = uid("PHASE:App:Sources")
    app_frameworks_phase = uid("PHASE:App:Frameworks")
    app_resources_phase = uid("PHASE:App:Resources")
    app_embed_ext_phase = uid("PHASE:App:EmbedExtensions")

    widget_sources_phase = uid("PHASE:Widget:Sources")
    widget_frameworks_phase = uid("PHASE:Widget:Frameworks")
    widget_resources_phase = uid("PHASE:Widget:Resources")

    test_sources_phase = uid("PHASE:Test:Sources")
    test_frameworks_phase = uid("PHASE:Test:Frameworks")
    test_resources_phase = uid("PHASE:Test:Resources")

    # Dependencies
    dep_app_widget = uid("DEP:App->Widget")
    proxy_app_widget = uid("PROXY:App->Widget")
    dep_test_app = uid("DEP:Test->App")
    proxy_test_app = uid("PROXY:Test->App")

    # Embed build file for widget extension
    embed_widget_bf = uid("BF:Embed:DaydropWidget.appex")

    # Build file records
    build_files = []
    app_source_bfs = []
    app_resource_bfs = []
    widget_source_bfs = []
    widget_resource_bfs = []
    test_source_bfs = []

    def add_bf(scope: str, path: str, target_list: list):
        bf_id = uid(f"BF:{scope}:{path}")
        ref_id = uid(f"REF:{path}")
        basename = os.path.basename(path)
        build_files.append(f"\t\t{bf_id} /* {basename} in {scope} */ = {{isa = PBXBuildFile; fileRef = {ref_id} /* {basename} */; }};")
        target_list.append((bf_id, basename))

    for f in SHARED_SWIFT + APP_SWIFT:
        add_bf("AppSources", f, app_source_bfs)
    for f in SHARED_RESOURCES + APP_RESOURCES:
        add_bf("AppResources", f, app_resource_bfs)

    for f in SHARED_SWIFT + WIDGET_SWIFT:
        add_bf("WidgetSources", f, widget_source_bfs)
    for f in SHARED_RESOURCES:
        add_bf("WidgetResources", f, widget_resource_bfs)

    for f in TEST_SWIFT:
        add_bf("TestSources", f, test_source_bfs)

    # Localized InfoPlist.strings variant groups
    app_info_vg = uid("VG:Daydrop:InfoPlist.strings")
    app_info_zh = uid("REF:Daydrop/zh-Hans.lproj/InfoPlist.strings")
    app_info_en = uid("REF:Daydrop/en.lproj/InfoPlist.strings")
    app_info_bf = uid("BF:AppResources:InfoPlist.strings")

    widget_info_vg = uid("VG:DaydropWidget:InfoPlist.strings")
    widget_info_zh = uid("REF:DaydropWidget/zh-Hans.lproj/InfoPlist.strings")
    widget_info_en = uid("REF:DaydropWidget/en.lproj/InfoPlist.strings")
    widget_info_bf = uid("BF:WidgetResources:InfoPlist.strings")

    build_files.append(f"\t\t{app_info_bf} /* InfoPlist.strings in AppResources */ = {{isa = PBXBuildFile; fileRef = {app_info_vg} /* InfoPlist.strings */; }};")
    app_resource_bfs.append((app_info_bf, "InfoPlist.strings"))

    build_files.append(f"\t\t{widget_info_bf} /* InfoPlist.strings in WidgetResources */ = {{isa = PBXBuildFile; fileRef = {widget_info_vg} /* InfoPlist.strings */; }};")
    widget_resource_bfs.append((widget_info_bf, "InfoPlist.strings"))

    build_files.append(
        f"\t\t{embed_widget_bf} /* DaydropWidget.appex in Embed Foundation Extensions */ = "
        f"{{isa = PBXBuildFile; fileRef = {widget_prod_id} /* DaydropWidget.appex */; "
        f"settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};"
    )

    # File references
    file_refs = []
    for f in all_files:
        ref_id = uid(f"REF:{f}")
        basename = os.path.basename(f)
        ft = file_type(f)
        file_refs.append(
            f'\t\t{ref_id} /* {basename} */ = {{isa = PBXFileReference; lastKnownFileType = {ft}; '
            f'name = "{basename}"; path = "{f}"; sourceTree = SOURCE_ROOT; }};'
        )

    file_refs.append(
        f'\t\t{app_info_zh} /* zh-Hans */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.strings; '
        f'name = "zh-Hans"; path = "Daydrop/zh-Hans.lproj/InfoPlist.strings"; sourceTree = SOURCE_ROOT; }};'
    )
    file_refs.append(
        f'\t\t{app_info_en} /* en */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.strings; '
        f'name = en; path = "Daydrop/en.lproj/InfoPlist.strings"; sourceTree = SOURCE_ROOT; }};'
    )
    file_refs.append(
        f'\t\t{widget_info_zh} /* zh-Hans */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.strings; '
        f'name = "zh-Hans"; path = "DaydropWidget/zh-Hans.lproj/InfoPlist.strings"; sourceTree = SOURCE_ROOT; }};'
    )
    file_refs.append(
        f'\t\t{widget_info_en} /* en */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.strings; '
        f'name = en; path = "DaydropWidget/en.lproj/InfoPlist.strings"; sourceTree = SOURCE_ROOT; }};'
    )

    file_refs.append(
        f'\t\t{app_prod_id} /* Daydrop.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; '
        f'includeInIndex = 0; path = Daydrop.app; sourceTree = BUILT_PRODUCTS_DIR; }};'
    )
    file_refs.append(
        f'\t\t{widget_prod_id} /* DaydropWidget.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; '
        f'includeInIndex = 0; path = DaydropWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }};'
    )
    file_refs.append(
        f'\t\t{test_prod_id} /* DaydropTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; '
        f'includeInIndex = 0; path = DaydropTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};'
    )

    # Groups
    main_group_id = uid("GROUP:Main")
    shared_group_id = uid("GROUP:Shared")
    app_group_id = uid("GROUP:Daydrop")
    widget_group_id = uid("GROUP:DaydropWidget")
    test_group_id = uid("GROUP:DaydropTests")
    products_group_id = uid("GROUP:Products")

    def group_children(paths):
        lines = []
        for p in paths:
            lines.append(f"\t\t\t\t{uid(f'REF:{p}')} /* {os.path.basename(p)} */,")
        return "\n".join(lines)

    # Configurations
    proj_id = uid("PROJECT:Daydrop")
    proj_cfg_list = uid("CFGLIST:Project")
    proj_debug = uid("CFG:Project:Debug")
    proj_release = uid("CFG:Project:Release")

    app_cfg_list = uid("CFGLIST:App")
    app_debug = uid("CFG:App:Debug")
    app_release = uid("CFG:App:Release")

    widget_cfg_list = uid("CFGLIST:Widget")
    widget_debug = uid("CFG:Widget:Debug")
    widget_release = uid("CFG:Widget:Release")

    test_cfg_list = uid("CFGLIST:Test")
    test_debug = uid("CFG:Test:Debug")
    test_release = uid("CFG:Test:Release")

    def bf_list(items):
        return "\n".join(f"\t\t\t\t{bf_id} /* {name} */," for bf_id, name in items)

    pbxproj = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_files)}
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		{proxy_app_widget} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {proj_id} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {widget_target_id};
			remoteInfo = DaydropWidget;
		}};
		{proxy_test_app} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {proj_id} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {app_target_id};
			remoteInfo = Daydrop;
		}};
/* End PBXContainerItemProxy section */

/* Begin PBXCopyFilesBuildPhase section */
		{app_embed_ext_phase} /* Embed Foundation Extensions */ = {{
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 13;
			files = (
				{embed_widget_bf} /* DaydropWidget.appex in Embed Foundation Extensions */,
			);
			name = "Embed Foundation Extensions";
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
{chr(10).join(file_refs)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{app_frameworks_phase} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{widget_frameworks_phase} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{test_frameworks_phase} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{main_group_id} = {{
			isa = PBXGroup;
			children = (
				{shared_group_id} /* Shared */,
				{app_group_id} /* Daydrop */,
				{widget_group_id} /* DaydropWidget */,
				{test_group_id} /* DaydropTests */,
				{products_group_id} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{shared_group_id} /* Shared */ = {{
			isa = PBXGroup;
			children = (
{group_children(SHARED_SWIFT + SHARED_RESOURCES)}
			);
			name = Shared;
			sourceTree = "<group>";
		}};
		{app_group_id} /* Daydrop */ = {{
			isa = PBXGroup;
			children = (
{group_children(APP_SWIFT + APP_RESOURCES + APP_EXTRA_FILES)}
				{app_info_vg} /* InfoPlist.strings */,
			);
			name = Daydrop;
			sourceTree = "<group>";
		}};
		{widget_group_id} /* DaydropWidget */ = {{
			isa = PBXGroup;
			children = (
{group_children(WIDGET_SWIFT + WIDGET_EXTRA_FILES)}
				{widget_info_vg} /* InfoPlist.strings */,
			);
			name = DaydropWidget;
			sourceTree = "<group>";
		}};
		{test_group_id} /* DaydropTests */ = {{
			isa = PBXGroup;
			children = (
{group_children(TEST_SWIFT)}
			);
			name = DaydropTests;
			sourceTree = "<group>";
		}};
		{products_group_id} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{app_prod_id} /* Daydrop.app */,
				{widget_prod_id} /* DaydropWidget.appex */,
				{test_prod_id} /* DaydropTests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{app_target_id} /* Daydrop */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {app_cfg_list} /* Build configuration list for PBXNativeTarget "Daydrop" */;
			buildPhases = (
				{app_sources_phase} /* Sources */,
				{app_frameworks_phase} /* Frameworks */,
				{app_resources_phase} /* Resources */,
				{app_embed_ext_phase} /* Embed Foundation Extensions */,
			);
			buildRules = (
			);
			dependencies = (
				{dep_app_widget} /* PBXTargetDependency */,
			);
			name = Daydrop;
			productName = Daydrop;
			productReference = {app_prod_id} /* Daydrop.app */;
			productType = "com.apple.product-type.application";
		}};
		{widget_target_id} /* DaydropWidget */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {widget_cfg_list} /* Build configuration list for PBXNativeTarget "DaydropWidget" */;
			buildPhases = (
				{widget_sources_phase} /* Sources */,
				{widget_frameworks_phase} /* Frameworks */,
				{widget_resources_phase} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = DaydropWidget;
			productName = DaydropWidget;
			productReference = {widget_prod_id} /* DaydropWidget.appex */;
			productType = "com.apple.product-type.app-extension";
		}};
		{test_target_id} /* DaydropTests */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {test_cfg_list} /* Build configuration list for PBXNativeTarget "DaydropTests" */;
			buildPhases = (
				{test_sources_phase} /* Sources */,
				{test_frameworks_phase} /* Frameworks */,
				{test_resources_phase} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				{dep_test_app} /* PBXTargetDependency */,
			);
			name = DaydropTests;
			productName = DaydropTests;
			productReference = {test_prod_id} /* DaydropTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{proj_id} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
				TargetAttributes = {{
					{test_target_id} = {{
						TestTargetID = {app_target_id};
					}};
				}};
			}};
			buildConfigurationList = {proj_cfg_list} /* Build configuration list for PBXProject "Daydrop" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				"zh-Hans",
				Base,
			);
			mainGroup = {main_group_id};
			productRefGroup = {products_group_id} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{app_target_id} /* Daydrop */,
				{widget_target_id} /* DaydropWidget */,
				{test_target_id} /* DaydropTests */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{app_resources_phase} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{bf_list(app_resource_bfs)}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{widget_resources_phase} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{bf_list(widget_resource_bfs)}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{test_resources_phase} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{app_sources_phase} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{bf_list(app_source_bfs)}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{widget_sources_phase} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{bf_list(widget_source_bfs)}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{test_sources_phase} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{bf_list(test_source_bfs)}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		{dep_app_widget} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {widget_target_id} /* DaydropWidget */;
			targetProxy = {proxy_app_widget} /* PBXContainerItemProxy */;
		}};
		{dep_test_app} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {app_target_id} /* Daydrop */;
			targetProxy = {proxy_test_app} /* PBXContainerItemProxy */;
		}};
/* End PBXTargetDependency section */

/* Begin PBXVariantGroup section */
		{app_info_vg} /* InfoPlist.strings */ = {{
			isa = PBXVariantGroup;
			children = (
				{app_info_zh} /* zh-Hans */,
				{app_info_en} /* en */,
			);
			name = InfoPlist.strings;
			sourceTree = "<group>";
		}};
		{widget_info_vg} /* InfoPlist.strings */ = {{
			isa = PBXVariantGroup;
			children = (
				{widget_info_zh} /* zh-Hans */,
				{widget_info_en} /* en */,
			);
			name = InfoPlist.strings;
			sourceTree = "<group>";
		}};
/* End PBXVariantGroup section */

/* Begin XCBuildConfiguration section */
		{proj_debug} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CODE_SIGN_IDENTITY = "-";
				COMBINE_HIDPI_IMAGES = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
			}};
			name = Debug;
		}};
		{proj_release} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CODE_SIGN_IDENTITY = "-";
				COMBINE_HIDPI_IMAGES = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				SWIFT_VERSION = 5.0;
			}};
			name = Release;
		}};
		{app_debug} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_ENTITLEMENTS = Daydrop/Daydrop.entitlements;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Manual;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Daydrop/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.daydrop.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
			}};
			name = Debug;
		}};
		{app_release} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_ENTITLEMENTS = Daydrop/Daydrop.entitlements;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Manual;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Daydrop/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.daydrop.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
			}};
			name = Release;
		}};
		{widget_debug} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				CODE_SIGN_ENTITLEMENTS = DaydropWidget/DaydropWidget.entitlements;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Manual;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = DaydropWidget/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
					"@executable_path/../../../../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.daydrop.app.widget;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
			}};
			name = Debug;
		}};
		{widget_release} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				CODE_SIGN_ENTITLEMENTS = DaydropWidget/DaydropWidget.entitlements;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Manual;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = DaydropWidget/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
					"@executable_path/../../../../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.daydrop.app.widget;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
			}};
			name = Release;
		}};
		{test_debug} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_IDENTITY = "-";
				GENERATE_INFOPLIST_FILE = YES;
				PRODUCT_BUNDLE_IDENTIFIER = com.daydrop.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Daydrop.app/Contents/MacOS/Daydrop";
			}};
			name = Debug;
		}};
		{test_release} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_IDENTITY = "-";
				GENERATE_INFOPLIST_FILE = YES;
				PRODUCT_BUNDLE_IDENTIFIER = com.daydrop.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Daydrop.app/Contents/MacOS/Daydrop";
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{proj_cfg_list} /* Build configuration list for PBXProject "Daydrop" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{proj_debug} /* Debug */,
				{proj_release} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Debug;
		}};
		{app_cfg_list} /* Build configuration list for PBXNativeTarget "Daydrop" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{app_debug} /* Debug */,
				{app_release} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Debug;
		}};
		{widget_cfg_list} /* Build configuration list for PBXNativeTarget "DaydropWidget" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{widget_debug} /* Debug */,
				{widget_release} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Debug;
		}};
		{test_cfg_list} /* Build configuration list for PBXNativeTarget "DaydropTests" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{test_debug} /* Debug */,
				{test_release} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Debug;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {proj_id} /* Project object */;
}}
"""

    with open(os.path.join(PROJ_DIR, "project.pbxproj"), "w", encoding="utf-8") as f:
        f.write(pbxproj)

    # Generate shared scheme for Daydrop
    xcscheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{app_target_id}"
               BuildableName = "Daydrop.app"
               BlueprintName = "Daydrop"
               ReferencedContainer = "container:Daydrop.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{test_target_id}"
               BuildableName = "DaydropTests.xctest"
               BlueprintName = "DaydropTests"
               ReferencedContainer = "container:Daydrop.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target_id}"
            BuildableName = "Daydrop.app"
            BlueprintName = "Daydrop"
            ReferencedContainer = "container:Daydrop.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    with open(os.path.join(SCHEME_DIR, "Daydrop.xcscheme"), "w", encoding="utf-8") as f:
        f.write(xcscheme)

    print("Generated Daydrop.xcodeproj and shared scheme successfully!")


if __name__ == "__main__":
    generate()
