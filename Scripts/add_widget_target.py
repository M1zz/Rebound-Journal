#!/usr/bin/env python3
"""위젯 확장 타깃을 pbxproj에 만들어 넣는다.

이 프로젝트는 objectVersion 56에 동기화된 폴더 그룹이 없다. 파일 하나를 더하는
것도 손으로 등록해야 하고(`add_sources_to_pbxproj.py`), 타깃 하나를 더하는 건
그보다 훨씬 많은 조각을 맞춰야 한다.

한 번만 실행한다. 두 번 돌리면 같은 타깃이 두 개 생긴다 — 그래서 맨 앞에서
이미 있는지 보고 그냥 나간다.

만들어 넣는 조각들:

  - 위젯 소스와 산출물(.appex)의 파일 참조, 그리고 이들을 담을 그룹
  - 위젯 타깃의 Sources / Frameworks / Resources 빌드 단계
  - 위젯 타깃의 Debug / Release 빌드 설정과 그 목록
  - 앱 타깃 쪽: .appex를 앱 안에 넣는 복사 단계, 그리고 의존 관계
    (이게 없으면 앱만 빌드되고 위젯은 기기에 올라가지 않는다)

앱과 위젯이 함께 쓰는 소스는 **파일 참조를 공유하고 PBXBuildFile만 새로
만든다.** 파일을 복사하면 조약돌이 두 벌이 되고, 한쪽만 고치는 날이 온다.
"""

import re
import secrets
import sys
from pathlib import Path

PROJECT = Path("Rebound Journal.xcodeproj/project.pbxproj")

APP_TARGET = "586F22872A33861C004C7410"
APP_BUILD_PHASES_ANCHOR = "586F22862A33861C004C7410 /* Resources */,"
MAIN_GROUP = "586F227F2A33861C004C7410"
PRODUCTS_GROUP = "586F22892A33861C004C7410"

WIDGET_NAME = "ReboundWidget"
WIDGET_BUNDLE_ID = "com.leeo.ReboundJournal.ReboundWidget"
APP_GROUP = "group.com.leeo.ReboundJournal"

# 위젯 타깃에서만 컴파일하는 소스.
OWN_SOURCES = ["TodayWidget.swift", "ReboundWidgetBundle.swift"]

# 앱과 함께 쓰는 소스. 이름으로 기존 파일 참조를 찾아 붙인다.
SHARED_SOURCES = [
    "PebbleTheme.swift",
    "PebbleView.swift",
    "PebbleMood.swift",
    "PebbleSnapshot.swift",
]


def new_id():
    """pbxproj가 쓰는 24자리 대문자 16진수 식별자."""
    return secrets.token_hex(12).upper()


def find_file_ref(src, filename):
    """이름으로 기존 PBXFileReference의 식별자를 찾는다."""
    match = re.search(
        r"^\t\t([0-9A-F]{24}) /\* %s \*/ = \{isa = PBXFileReference;" % re.escape(filename),
        src,
        re.MULTILINE,
    )
    if not match:
        sys.exit("파일 참조를 못 찾았다: %s — 먼저 앱 타깃에 등록해야 한다" % filename)
    return match.group(1)


def insert_before(src, marker, text):
    index = src.index(marker)
    return src[:index] + text + src[index:]


def main():
    src = PROJECT.read_text(encoding="utf-8")

    if WIDGET_NAME + ".appex" in src:
        print("이미 있다. 아무것도 하지 않는다.")
        return

    ids = {key: new_id() for key in [
        "product", "group", "target", "sources", "frameworks", "resources",
        "embed", "embed_buildfile", "proxy", "dependency",
        "config_list", "config_debug", "config_release",
        "info_plist", "entitlements",
    ]}

    # ---- 파일 참조 -------------------------------------------------------
    refs = [
        '\t\t%s /* %s.appex */ = {isa = PBXFileReference; explicitFileType = '
        '"wrapper.app-extension"; includeInIndex = 0; path = "%s.appex"; '
        'sourceTree = BUILT_PRODUCTS_DIR; };\n' % (ids["product"], WIDGET_NAME, WIDGET_NAME),
        '\t\t%s /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; '
        'path = Info.plist; sourceTree = "<group>"; };\n' % ids["info_plist"],
        '\t\t%s /* %s.entitlements */ = {isa = PBXFileReference; lastKnownFileType = '
        'text.plist.entitlements; path = %s.entitlements; sourceTree = "<group>"; };\n'
        % (ids["entitlements"], WIDGET_NAME, WIDGET_NAME),
    ]

    own = {}
    for name in OWN_SOURCES:
        own[name] = {"file": new_id(), "build": new_id()}
        refs.append(
            '\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; '
            'path = %s; sourceTree = "<group>"; };\n' % (own[name]["file"], name, name)
        )

    src = insert_before(src, "/* End PBXFileReference section */", "".join(refs))

    # ---- 빌드 파일 -------------------------------------------------------
    build_files = [
        '\t\t%s /* %s.appex in Embed Foundation Extensions */ = {isa = PBXBuildFile; '
        'fileRef = %s /* %s.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };\n'
        % (ids["embed_buildfile"], WIDGET_NAME, ids["product"], WIDGET_NAME),
    ]
    for name in OWN_SOURCES:
        build_files.append(
            '\t\t%s /* %s in Sources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };\n'
            % (own[name]["build"], name, own[name]["file"], name)
        )

    shared = {}
    for name in SHARED_SOURCES:
        shared[name] = {"file": find_file_ref(src, name), "build": new_id()}
        build_files.append(
            '\t\t%s /* %s in Sources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };\n'
            % (shared[name]["build"], name, shared[name]["file"], name)
        )

    src = insert_before(src, "/* End PBXBuildFile section */", "".join(build_files))

    # ---- 그룹 -----------------------------------------------------------
    children = "".join(
        "\t\t\t\t%s /* %s */,\n" % (own[n]["file"], n) for n in OWN_SOURCES
    )
    group = (
        '\t\t%s /* %s */ = {\n'
        '\t\t\tisa = PBXGroup;\n'
        '\t\t\tchildren = (\n'
        '%s'
        '\t\t\t\t%s /* Info.plist */,\n'
        '\t\t\t\t%s /* %s.entitlements */,\n'
        '\t\t\t);\n'
        '\t\t\tpath = %s;\n'
        '\t\t\tsourceTree = "<group>";\n'
        '\t\t};\n'
        % (ids["group"], WIDGET_NAME, children,
           ids["info_plist"], ids["entitlements"], WIDGET_NAME, WIDGET_NAME)
    )
    src = insert_before(src, "/* End PBXGroup section */", group)

    # 최상위 그룹과 Products에 달아 준다.
    src = src.replace(
        "\t\t\t\t%s /* Products */,\n" % PRODUCTS_GROUP,
        "\t\t\t\t%s /* %s */,\n\t\t\t\t%s /* Products */,\n"
        % (ids["group"], WIDGET_NAME, PRODUCTS_GROUP),
        1,
    )
    src = re.sub(
        r"(\t\t%s /\* Products \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n)"
        % PRODUCTS_GROUP,
        r"\g<1>\t\t\t\t%s /* %s.appex */,\n" % (ids["product"], WIDGET_NAME),
        src,
        count=1,
    )

    # ---- 빌드 단계 -------------------------------------------------------
    widget_sources = "".join(
        "\t\t\t\t%s /* %s in Sources */,\n" % (own[n]["build"], n) for n in OWN_SOURCES
    ) + "".join(
        "\t\t\t\t%s /* %s in Sources */,\n" % (shared[n]["build"], n) for n in SHARED_SOURCES
    )

    src = insert_before(
        src,
        "/* End PBXSourcesBuildPhase section */",
        '\t\t%s /* Sources */ = {\n'
        '\t\t\tisa = PBXSourcesBuildPhase;\n'
        '\t\t\tbuildActionMask = 2147483647;\n'
        '\t\t\tfiles = (\n%s\t\t\t);\n'
        '\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        '\t\t};\n' % (ids["sources"], widget_sources),
    )

    src = insert_before(
        src,
        "/* End PBXFrameworksBuildPhase section */",
        '\t\t%s /* Frameworks */ = {\n'
        '\t\t\tisa = PBXFrameworksBuildPhase;\n'
        '\t\t\tbuildActionMask = 2147483647;\n'
        '\t\t\tfiles = (\n\t\t\t);\n'
        '\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        '\t\t};\n' % ids["frameworks"],
    )

    src = insert_before(
        src,
        "/* End PBXResourcesBuildPhase section */",
        '\t\t%s /* Resources */ = {\n'
        '\t\t\tisa = PBXResourcesBuildPhase;\n'
        '\t\t\tbuildActionMask = 2147483647;\n'
        '\t\t\tfiles = (\n\t\t\t);\n'
        '\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        '\t\t};\n' % ids["resources"],
    )

    # 앱 안에 .appex를 넣는 복사 단계. 없으면 위젯이 기기에 올라가지 않는다.
    copy_phase = (
        '/* Begin PBXCopyFilesBuildPhase section */\n'
        '\t\t%s /* Embed Foundation Extensions */ = {\n'
        '\t\t\tisa = PBXCopyFilesBuildPhase;\n'
        '\t\t\tbuildActionMask = 2147483647;\n'
        '\t\t\tdstPath = "";\n'
        '\t\t\tdstSubfolderSpec = 13;\n'
        '\t\t\tfiles = (\n'
        '\t\t\t\t%s /* %s.appex in Embed Foundation Extensions */,\n'
        '\t\t\t);\n'
        '\t\t\tname = "Embed Foundation Extensions";\n'
        '\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        '\t\t};\n'
        '/* End PBXCopyFilesBuildPhase section */\n\n'
        % (ids["embed"], ids["embed_buildfile"], WIDGET_NAME)
    )
    src = insert_before(src, "/* Begin PBXFileReference section */", copy_phase)

    # ---- 의존 관계 -------------------------------------------------------
    proxy = (
        '/* Begin PBXContainerItemProxy section */\n'
        '\t\t%s /* PBXContainerItemProxy */ = {\n'
        '\t\t\tisa = PBXContainerItemProxy;\n'
        '\t\t\tcontainerPortal = 586F22802A33861C004C7410 /* Project object */;\n'
        '\t\t\tproxyType = 1;\n'
        '\t\t\tremoteGlobalIDString = %s;\n'
        '\t\t\tremoteInfo = %s;\n'
        '\t\t};\n'
        '/* End PBXContainerItemProxy section */\n\n'
        % (ids["proxy"], ids["target"], WIDGET_NAME)
    )
    src = insert_before(src, "/* Begin PBXCopyFilesBuildPhase section */", proxy)

    dependency = (
        '/* Begin PBXTargetDependency section */\n'
        '\t\t%s /* PBXTargetDependency */ = {\n'
        '\t\t\tisa = PBXTargetDependency;\n'
        '\t\t\ttarget = %s /* %s */;\n'
        '\t\t\ttargetProxy = %s /* PBXContainerItemProxy */;\n'
        '\t\t};\n'
        '/* End PBXTargetDependency section */\n\n'
        % (ids["dependency"], ids["target"], WIDGET_NAME, ids["proxy"])
    )
    src = insert_before(src, "/* Begin XCBuildConfiguration section */", dependency)

    # ---- 위젯 타깃 -------------------------------------------------------
    target = (
        '\t\t%s /* %s */ = {\n'
        '\t\t\tisa = PBXNativeTarget;\n'
        '\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXNativeTarget "%s" */;\n'
        '\t\t\tbuildPhases = (\n'
        '\t\t\t\t%s /* Sources */,\n'
        '\t\t\t\t%s /* Frameworks */,\n'
        '\t\t\t\t%s /* Resources */,\n'
        '\t\t\t);\n'
        '\t\t\tbuildRules = (\n\t\t\t);\n'
        '\t\t\tdependencies = (\n\t\t\t);\n'
        '\t\t\tname = %s;\n'
        '\t\t\tproductName = %s;\n'
        '\t\t\tproductReference = %s /* %s.appex */;\n'
        '\t\t\tproductType = "com.apple.product-type.app-extension";\n'
        '\t\t};\n'
        % (ids["target"], WIDGET_NAME, ids["config_list"], WIDGET_NAME,
           ids["sources"], ids["frameworks"], ids["resources"],
           WIDGET_NAME, WIDGET_NAME, ids["product"], WIDGET_NAME)
    )
    src = insert_before(src, "/* End PBXNativeTarget section */", target)

    # 앱 타깃에 복사 단계와 의존 관계를 달아 준다.
    src = src.replace(
        "\t\t\t\t%s\n\t\t\t);\n\t\t\tbuildRules" % APP_BUILD_PHASES_ANCHOR,
        "\t\t\t\t%s\n\t\t\t\t%s /* Embed Foundation Extensions */,\n\t\t\t);\n\t\t\tbuildRules"
        % (APP_BUILD_PHASES_ANCHOR, ids["embed"]),
        1,
    )
    src = src.replace(
        "\t\t\tdependencies = (\n\t\t\t);\n\t\t\tname = \"Rebound Journal\";",
        "\t\t\tdependencies = (\n\t\t\t\t%s /* PBXTargetDependency */,\n\t\t\t);\n"
        "\t\t\tname = \"Rebound Journal\";" % ids["dependency"],
        1,
    )

    # ---- 빌드 설정 -------------------------------------------------------
    def config(config_id, name, extra):
        return (
            '\t\t%s /* %s */ = {\n'
            '\t\t\tisa = XCBuildConfiguration;\n'
            '\t\t\tbuildSettings = {\n'
            '\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;\n'
            '\t\t\t\tCODE_SIGN_ENTITLEMENTS = "%s/%s.entitlements";\n'
            '\t\t\t\tCODE_SIGN_STYLE = Automatic;\n'
            '\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n'
            '\t\t\t\tDEVELOPMENT_TEAM = QGAQ3AY3R3;\n'
            '\t\t\t\tGENERATE_INFOPLIST_FILE = YES;\n'
            '\t\t\t\tINFOPLIST_FILE = "%s/Info.plist";\n'
            '\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "징검돌";\n'
            '\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "";\n'
            '\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 26.0;\n'
            '\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\n'
            '\t\t\t\t\t"$(inherited)",\n'
            '\t\t\t\t\t"@executable_path/Frameworks",\n'
            '\t\t\t\t\t"@executable_path/../../Frameworks",\n'
            '\t\t\t\t);\n'
            '\t\t\t\tMARKETING_VERSION = 1.0.10;\n'
            '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = %s;\n'
            '\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";\n'
            '\t\t\t\tSKIP_INSTALL = YES;\n'
            '\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;\n'
            '\t\t\t\tSWIFT_VERSION = 5.0;\n'
            '\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";\n'
            '%s'
            '\t\t\t};\n'
            '\t\t\tname = %s;\n'
            '\t\t};\n'
            % (config_id, name, WIDGET_NAME, WIDGET_NAME, WIDGET_NAME,
               WIDGET_BUNDLE_ID, extra, name)
        )

    src = insert_before(
        src,
        "/* End XCBuildConfiguration section */",
        config(ids["config_debug"], "Debug",
               '\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";\n'
               '\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";\n')
        + config(ids["config_release"], "Release",
                 '\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;\n'),
    )

    src = insert_before(
        src,
        "/* End XCConfigurationList section */",
        '\t\t%s /* Build configuration list for PBXNativeTarget "%s" */ = {\n'
        '\t\t\tisa = XCConfigurationList;\n'
        '\t\t\tbuildConfigurations = (\n'
        '\t\t\t\t%s /* Debug */,\n'
        '\t\t\t\t%s /* Release */,\n'
        '\t\t\t);\n'
        '\t\t\tdefaultConfigurationIsVisible = 0;\n'
        '\t\t\tdefaultConfigurationName = Release;\n'
        '\t\t};\n'
        % (ids["config_list"], WIDGET_NAME, ids["config_debug"], ids["config_release"]),
    )

    # ---- 프로젝트에 등록 --------------------------------------------------
    src = src.replace(
        "\t\t\t\t586F22872A33861C004C7410 /* Rebound Journal */,\n\t\t\t);",
        "\t\t\t\t586F22872A33861C004C7410 /* Rebound Journal */,\n"
        "\t\t\t\t%s /* %s */,\n\t\t\t);" % (ids["target"], WIDGET_NAME),
        1,
    )
    src = src.replace(
        "\t\t\t\t\t586F22872A33861C004C7410 = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 14.3;\n\t\t\t\t\t};",
        "\t\t\t\t\t586F22872A33861C004C7410 = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 14.3;\n\t\t\t\t\t};\n"
        "\t\t\t\t\t%s = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 26.0;\n\t\t\t\t\t};" % ids["target"],
        1,
    )

    PROJECT.write_text(src, encoding="utf-8")
    print("위젯 타깃을 만들었다: %s (%s)" % (WIDGET_NAME, WIDGET_BUNDLE_ID))
    print("앱 그룹: %s" % APP_GROUP)


if __name__ == "__main__":
    main()
