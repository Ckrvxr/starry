cmake_minimum_required(VERSION 3.24)

project(Starry VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Quick Qml Network OpenGL QuickControls2)
find_package(PkgConfig REQUIRED)
pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)

qt_standard_project_setup(REQUIRES 6.5)
qt_policy(SET QTP0004 NEW)

qt_add_executable(starry
    src/main.cpp
    src/embyclient.cpp
    src/embyclient.h
    src/mpvplayer.cpp
    src/mpvplayer.h
    src/macoswindow.cpp
)

if(APPLE)
    enable_language(OBJCXX)
    target_sources(starry PRIVATE src/macoswindow.mm)
    target_link_libraries(starry PRIVATE "-framework QuartzCore")
endif()

qt_add_qml_module(starry
    URI Starry
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/components/AccentButton.qml
        qml/components/MediaCard.qml
        qml/components/PlayerView.qml
        qml/components/SidebarButton.qml
)

target_link_libraries(starry PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
    Qt6::Network
    Qt6::OpenGL
    Qt6::QuickControls2
    PkgConfig::MPV
)

target_compile_definitions(starry PRIVATE
    STARRY_VERSION="${PROJECT_VERSION}"
)

set_target_properties(starry PROPERTIES
    OUTPUT_NAME "Starry"
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_GUI_IDENTIFIER "app.starry.player"
    MACOSX_BUNDLE_BUNDLE_NAME "Starry"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    WIN32_EXECUTABLE TRUE
)

include(GNUInstallDirs)
install(TARGETS starry
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
