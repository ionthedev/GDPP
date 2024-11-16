#!/bin/bash

# Function to detect the OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
    else
        echo "Cannot detect OS"
        exit 1
    fi
}

# Function to check if script is run with sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run with sudo"
        exit 1
    fi
}

# Function to install packages based on OS
install_packages() {
    case "$OS" in
        *"Ubuntu"*|*"Debian"*)
            echo "Installing packages for Ubuntu/Debian..."
            apt-get update
            apt-get install -y \
                build-essential \
                scons \
                pkg-config \
                libx11-dev \
                libxcursor-dev \
                libxinerama-dev \
                libgl1-mesa-dev \
                libglu1-mesa-dev \
                libasound2-dev \
                libpulse-dev \
                libudev-dev \
                libxi-dev \
                libxrandr-dev \
                libwayland-dev
            ;;

        *"Arch"*)
            echo "Installing packages for Arch Linux..."
            pacman -Sy --noconfirm --needed \
                scons \
                pkgconf \
                gcc \
                libxcursor \
                libxinerama \
                libxi \
                libxrandr \
                wayland-utils \
                mesa \
                glu \
                libglvnd \
                alsa-lib \
                pulseaudio
            ;;

        *"Fedora"*)
            echo "Installing packages for Fedora..."
            dnf install -y \
                scons \
                pkgconfig \
                libX11-devel \
                libXcursor-devel \
                libXrandr-devel \
                libXinerama-devel \
                libXi-devel \
                wayland-devel \
                mesa-libGL-devel \
                mesa-libGLU-devel \
                alsa-lib-devel \
                pulseaudio-libs-devel \
                libudev-devel \
                gcc-c++ \
                libstdc++-static \
                libatomic-static
            ;;

        *)
            echo "Unsupported OS: $OS"
            exit 1
            ;;
    esac
}

#Asks what the project is going to be called
do_the_thing() {
    echo "What is the name of your project (No spaces please):"
    read project_name

    echo "What version of Godot are you targeting? ('3.x - 4.x' [Example: 4.3]):"
    read godot_version

    echo "Awesome, lets get the bindings out of the way"
    git init
    git submodule add -b ${godot_version} https://github.com/godotengine/godot-cpp
    # Create SConstruct file
    cat > SConstruct << EOF
#!/usr/bin/env python

# Define project name
project_name = "${project_name}"  # Generated project name

env = SConscript("../SConstruct")
# For the reference:
# - CCFLAGS are compilation flags shared between C and C++
# - CFLAGS are for C-specific compilation flags
# - CXXFLAGS are for C++-specific compilation flags
# - CPPFLAGS are for pre-processor flags
# - CPPDEFINES are for pre-processor defines
# - LINKFLAGS are for linking flags

# tweak this if you want to use different folders, or more folders, to store your source code in.
env.Append(CPPPATH=["src/"])
sources = Glob("src/*.cpp")

if env["target"] in ["editor", "template_debug"]:
    doc_data = env.GodotCPPDocData("src/gen/doc_data.gen.cpp", source=Glob("doc_classes/*.xml"))
    sources.append(doc_data)

if env["platform"] == "macos":
    library = env.SharedLibrary(
        "project/bin/{}.{}.{}.framework/{}.{}.{}".format(
            project_name,
            env["platform"],
            env["target"],
            project_name,
            env["platform"],
            env["target"]
        ),
        source=sources,
    )
elif env["platform"] == "ios":
    if env["ios_simulator"]:
        library = env.StaticLibrary(
            "project/bin/{}.{}.{}.simulator.a".format(
                project_name,
                env["platform"],
                env["target"]
                ),
            source=sources,
        )
    else:
        library = env.StaticLibrary(
            "project/bin/{}.{}.{}.a".format(
                project_name,
                env["platform"],
                env["target"]
                ),
            source=sources,
        )
else:
    library = env.SharedLibrary(
        "project/bin/{}{}{}".format(
            project_name,
            env["suffix"],
            env["SHLIBSUFFIX"]
            ),
        source=sources,
    )

env.NoCache(library)
Default(library)
EOF

# Create the GDExtension file
cat > "project/bin/${project_name}.gdextension" << EOF
[configuration]
entry_symbol = "${project_name}entry_point"
compatibility_minimum = "${godot_version}"
reloadable = true

[libraries]
macos.debug = "res://bin/lib${project_name}.macos.template_debug.framework"
macos.release = "res://bin/lib${project_name}.macos.template_release.framework"
ios.debug = "res://bin/lib${project_name}.ios.template_debug.xcframework"
ios.release = "res://bin/lib${project_name}.ios.template_release.xcframework"
windows.debug.x86_32 = "res://bin/lib${project_name}.windows.template_debug.x86_32.dll"
windows.release.x86_32 = "res://bin/lib${project_name}.windows.template_release.x86_32.dll"
windows.debug.x86_64 = "res://bin/lib${project_name}.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://bin/lib${project_name}.windows.template_release.x86_64.dll"
linux.debug.x86_64 = "res://bin/lib${project_name}.linux.template_debug.x86_64.so"
linux.release.x86_64 = "res://bin/lib${project_name}.linux.template_release.x86_64.so"
linux.debug.arm64 = "res://bin/lib${project_name}.linux.template_debug.arm64.so"
linux.release.arm64 = "res://bin/lib${project_name}.linux.template_release.arm64.so"
linux.debug.rv64 = "res://bin/lib${project_name}.linux.template_debug.rv64.so"
linux.release.rv64 = "res://bin/lib${project_name}.linux.template_release.rv64.so"
android.debug.x86_64 = "res://bin/lib${project_name}.android.template_debug.x86_64.so"
android.release.x86_64 = "res://bin/lib${project_name}.android.template_release.x86_64.so"
android.debug.arm64 = "res://bin/lib${project_name}.android.template_debug.arm64.so"
android.release.arm64 = "res://bin/lib${project_name}.android.template_release.arm64.so"

[dependencies]
ios.debug = {
"res://bin/libgodot-cpp.ios.template_debug.xcframework": ""
}
ios.release = {
"res://bin/libgodot-cpp.ios.template_release.xcframework": ""
}
EOF


    cd godot-cpp
    git submodule update --init
    echo "Okay, building the bindings now, this may take a second."
    scons platform=linux custom_api_file=./gdextension/extension_api.json > build.log 2>&1 &
    PID=$!
    show_progress $PID
    wait $PID
    if [ $? -eq 0 ]; then
        echo "AWESOME! The bindings have been compiled successfully!"
    else
        echo "Build failed. Check build.log for details."
        exit 1
    fi
    echo "Alright, making a compile_commands.json file just in case, it may be helpful."
    scons platform=linux compile_commands.json
    cd ..

    cat > "src/register_types.h" << EOF
#pragma once

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void ${project_name}_initialize(ModuleInitializationLevel p_level);
void ${project_name}_terminate(ModuleInitializationLevel p_level);
EOF


    cat > "src/register_types.cpp" << EOF
    #include "register_types.h"

    #include <gdextension_interface.h>
    #include <godot_cpp/core/class_db.hpp>
    #include <godot_cpp/core/defs.hpp>
    #include <godot_cpp/classes/engine.hpp>
    #include <godot_cpp/godot.hpp>

    #include "my_node.hpp"
    #include "my_singleton.hpp"

    using namespace godot;

    static MySingleton *_my_singleton;

    void ${project_name}_initialize(ModuleInitializationLevel p_level)
    {
    if (p_level == MODULE_INITIALIZATION_LEVEL_SCENE)
    {
    ClassDB::register_class<MyNode>();
    ClassDB::register_class<MySingleton>();

    _my_singleton = memnew(MySingleton);
    Engine::get_singleton()->register_singleton("MySingleton", MySingleton::get_singleton());
    }
    }

    void ${project_name}_terminate(ModuleInitializationLevel p_level)
    {
    if (p_level == MODULE_INITIALIZATION_LEVEL_SCENE)
    {
    Engine::get_singleton()->unregister_singleton("MySingleton");
    memdelete(_my_singleton);
    }
    }

    extern "C"
    {
    GDExtensionBool GDE_EXPORT ${project_name}entry_point(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization)
    {
    godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

    init_obj.register_initializer(${project_name}_initialize);
    init_obj.register_terminator(${project_name}_terminate);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

    return init_obj.init();
    }
    }
EOF

    cat > "src/my_node.hpp" << EOF
    #pragma once

    #include <godot_cpp/classes/node.hpp>
    #include <godot_cpp/core/class_db.hpp>

    using namespace godot;

    class MyNode : public Node
    {
	GDCLASS(MyNode, Node);

    protected:
	static void _bind_methods();

    public:
	MyNode();
	~MyNode();

	void _ready() override;
	void _process(double delta) override;

	void hello_node();
    };
EOF

    cat > "src/my_node.cpp" << EOF
    #include "my_node.hpp"

    #include <godot_cpp/core/class_db.hpp>
    #include <godot_cpp/variant/utility_functions.hpp>

    using namespace godot;

    void MyNode::_bind_methods()
    {
    ClassDB::bind_method(D_METHOD("hello_node"), &MyNode::hello_node);
    }

    MyNode::MyNode()
    {
    }

    MyNode::~MyNode()
    {
    }

    // Override built-in methods with your own logic. Make sure to declare them in the header as well!

    void MyNode::_ready()
    {
    }

    void MyNode::_process(double delta)
    {
    }

    void MyNode::hello_node()
    {
    UtilityFunctions::print("Hello GDExtension Node!");
    }
EOF

    cat > "src/my_singleton.hpp" << EOF
    #pragma once

    #include <godot_cpp/classes/object.hpp>
    #include <godot_cpp/core/class_db.hpp>

    using namespace godot;

    class MySingleton : public Object
    {
    GDCLASS(MySingleton, Object);

    static MySingleton *singleton;

    protected:
    static void _bind_methods();

    public:
    static MySingleton *get_singleton();

    MySingleton();
    ~MySingleton();

    void hello_singleton();
    };
EOF

    cat > "src/my_singleton.cpp" << EOF
    #include "my_singleton.hpp"

    #include <godot_cpp/core/class_db.hpp>
    #include <godot_cpp/variant/utility_functions.hpp>

    using namespace godot;

    MySingleton *MySingleton::singleton = nullptr;

    void MySingleton::_bind_methods()
    {
	ClassDB::bind_method(D_METHOD("hello_singleton"), &MySingleton::hello_singleton);
    }

    MySingleton *MySingleton::get_singleton()
    {
	return singleton;
    }

    MySingleton::MySingleton()
    {
	ERR_FAIL_COND(singleton != nullptr);
	singleton = this;
    }

    MySingleton::~MySingleton()
    {
	ERR_FAIL_COND(singleton != this);
	singleton = nullptr;
    }

    void MySingleton::hello_singleton()
    {
	UtilityFunctions::print("Hello GDExtension Singleton!");
    }
EOF

    scons platform=linux
    scons platform=linux compile_commands.json
    echo "Alrighty! That's it! Have a ball and don't blow your leg off"
}

show_progress() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    local progress=0
    local width=40

    # Hide cursor
    tput civis

    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%-${width}s] %c " "$(printf '#%.0s' $(seq 1 $((progress % width))))" "${spinstr}"
        local spinstr=$temp${spinstr%"$temp"}
        printf "\r"
        sleep $delay
        ((progress++))
    done

    # Show cursor and move to next line
    printf " [%-${width}s] Done!\n" "$(printf '#%.0s' $(seq 1 $width))"
    tput cnorm
}

# Function to set up project structure
setup_project_structure() {
    # Create project directories
    mkdir -p src/
    mkdir -p doc_classes/
    mkdir -p project/
    mkdir -p project/bin/
}

fix_permissions() {
    echo_status "Fixing file permissions..."
    # Get the actual user who ran the script with sudo
    ACTUAL_USER=$SUDO_USER
    ACTUAL_GROUP=$(id -gn $SUDO_USER)

    echo_info "Changing ownership to $ACTUAL_USER:$ACTUAL_GROUP"
    chown -R $ACTUAL_USER:$ACTUAL_GROUP ./src/
    chown -R $ACTUAL_USER:$ACTUAL_GROUP ./project/
    chown -R $ACTUAL_USER:$ACTUAL_GROUP ./SConstruct
    chown -R $ACTUAL_USER:$ACTUAL_GROUP ./godot-cpp/
    chown -R $ACTUAL_USER:$ACTUAL_GROUP ./doc_classes/

    # Then set permissions
    chmod -R 755 ./src/
    chmod -R 755 ./project/
    chmod -R 755 ./SConstruct
    chmod -R 755 ./godot-cpp/
    chmod -R 755 ./doc_classes/

    echo_success "File permissions fixed!"
}


# Main execution
echo "Starting setup..."
detect_os
check_sudo
echo "Welcome to GDPP - GDExtension Bootstrapper for C++"
echo "Before we get started, let me grab a few things you will need"
install_packages
echo "Setting up project structure"
setup_project_structure
echo "Now that THAT is done, I have a few questions for you"
do_the_thing
fix_permissions

echo "Setup complete! Your development environment is ready."
echo "You can now build the project using 'make' and run it with './build/program'"
