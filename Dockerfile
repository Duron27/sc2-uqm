# syntax=docker/dockerfile:labs
FROM rockylinux:9

#Set build type : release, RelWithDebInfo, debug
ENV BUILD_TYPE=release

# App versions - change settings here
ARG LIBJPEG_TURBO_VERSION=3.1.0
ARG LIBPNG_VERSION=1.6.48
ARG FREETYPE2_VERSION=2.13.3
ARG OBOE_VERSION=1.9.3
ARG OPENAL_VERSION=1.24.3
ARG BOOST_VERSION=1.88.0
ARG LIBICU_VERSION=70-1
ARG FFMPEG_VERSION=7.1.1
ARG SDL2_VERSION=2.32.4
ARG BULLET_VERSION=3.25
ARG ZLIB_VERSION=1.3.1
ARG LIBXML2_VERSION=2.14.3
ARG MYGUI_VERSION=3.4.3
ARG GL4ES_VERSION=2d7949c0ad55e850f9aa9ed28f5e6ff6490984ee
ARG COLLADA_DOM_VERSION=2.5.0
ARG OSG_VERSION=495b370da37d9e3c739914a190f9821884619a4a
ARG LZ4_VERSION=1.10.0
ARG LUAJIT_VERSION=2.1.ROLLING
ARG OPENMW_VERSION=98973426a4d2ee16abcf20c320a06c3119cbd679
ARG NDK_VERSION=27.2.12479018
ARG SDK_CMDLINE_TOOLS=10406996_latest
ARG JAVA_VERSION=21
# NDK 29 29.0.13113456
# Version of Release
ARG APP_VERSION=Alpha

RUN dnf install -y dnf-plugins-core && dnf config-manager --set-enabled crb && dnf install -y epel-release
RUN dnf install -y https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-9.noarch.rpm \
    && dnf install -y xz p7zip bzip2 libstdc++-devel glibc-devel zip unzip libcurl-devel which zlib-devel wget python-devel doxygen nano gcc-c++ libxcb-devel git java-${JAVA_VERSION}-openjdk-devel cmake patch

RUN mkdir -p ${HOME}/prefix
RUN mkdir -p ${HOME}/src

# Set the installation Dir
ENV PREFIX=/root/prefix
RUN cd ${HOME}/src && wget https://github.com/unicode-org/icu/archive/refs/tags/release-${LIBICU_VERSION}.zip && unzip -o ${HOME}/src/release-${LIBICU_VERSION}.zip && rm -rf release-${LIBICU_VERSION}.zip
RUN wget https://dl.google.com/android/repository/commandlinetools-linux-${SDK_CMDLINE_TOOLS}.zip && unzip commandlinetools-linux-${SDK_CMDLINE_TOOLS}.zip && mkdir -p ${HOME}/Android/cmdline-tools/ && mv cmdline-tools/ ${HOME}/Android/cmdline-tools/latest && rm commandlinetools-linux-${SDK_CMDLINE_TOOLS}.zip


# Setup sdkmanager and all tools
ENV ANDROID_HOME=/root/Android
RUN yes | ~/Android/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null
RUN ~/Android/cmdline-tools/latest/bin/sdkmanager --install "ndk;${NDK_VERSION}" "platforms;android-34" "platform-tools" "build-tools;34.0.0" --channel=0
RUN yes | ~/Android/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null

#Setup ICU for the Host
RUN mkdir -p ${HOME}/src/icu-host-build && cd $_ && ${HOME}/src/icu-release-70-1/icu4c/source/configure --disable-tests --disable-samples --disable-icuio --disable-extras CC="gcc" CXX="g++" && make -j $(nproc)
ENV PATH=$PATH:/root/Android/cmdline-tools/latest/bin/:/root/Android/ndk/${NDK_VERSION}/:/root/Android/ndk/${NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64:/root/Android/ndk/${NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64/bin:/root/prefix/include:/root/prefix/lib:/root/prefix/:/root/.cargo/bin

#Setup Python for the Host
RUN cd ${HOME}/src && wget https://www.python.org/ftp/python/3.13.4/Python-3.13.4.tar.xz && \
    tar -xf Python-3.13.4.tar.xz && \
    cd Python-3.13.4 && \
    ./configure --prefix=${HOME}/src/python-host-install && \
    make -j$(nproc) && make install

# NDK Settings
ENV API=24
ENV ABI=arm64-v8a
ENV ARCH=aarch64
ENV NDK_TRIPLET=${ARCH}-linux-android
ENV TOOLCHAIN=/root/Android/ndk/${NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64
ENV NDK_SYSROOT=${TOOLCHAIN}/sysroot/
ENV ANDROID_SYSROOT=${TOOLCHAIN}/sysroot/
 # ANDROID_NDK is needed for SDL2 cmake
ENV ANDROID_NDK=/root/Android/ndk/${NDK_VERSION}/
ENV AR=${TOOLCHAIN}/bin/llvm-ar
ENV LD=${TOOLCHAIN}/bin/ld
ENV RANLIB=${TOOLCHAIN}/bin/llvm-ranlib
ENV STRIP=${TOOLCHAIN}/bin/llvm-strip
ENV CC=${TOOLCHAIN}/bin/${NDK_TRIPLET}${API}-clang
ENV CXX=${TOOLCHAIN}/bin/${NDK_TRIPLET}${API}-clang++
ENV clang=${TOOLCHAIN}/bin/${NDK_TRIPLET}${API}-clang
ENV clang++=${TOOLCHAIN}/bin/${NDK_TRIPLET}${API}-clang++
ENV PKG_CONFIG_LIBDIR=${PREFIX}/lib/pkgconfig

# Global C, CXX and LDFLAGS
ENV CFLAGS="-fPIC -O3 -flto=thin"
ENV CXXFLAGS="-fPIC -O3 -frtti -fexceptions -flto=thin"
ENV LDFLAGS="-fPIC -Wl,--undefined-version -flto=thin -fuse-ld=lld"

ENV COMMON_CMAKE_ARGS \
  "-DCMAKE_TOOLCHAIN_FILE=/root/Android/ndk/${NDK_VERSION}/build/cmake/android.toolchain.cmake" \
  "-DANDROID_ABI=${ABI}" \
  "-DANDROID_PLATFORM=${API}" \
  "-DANDROID_STL=c++_shared" \
  "-DANDROID_CPP_FEATURES=" \
  "-DANDROID_ALLOW_UNDEFINED_VERSION_SCRIPT_SYMBOLS=ON" \
  "-DCMAKE_BUILD_TYPE=$BUILD_TYPE" \
  "-DCMAKE_C_FLAGS=-I${PREFIX}" \
  "-DCMAKE_DEBUG_POSTFIX=" \
  "-DCMAKE_INSTALL_PREFIX=${PREFIX}" \
  "-DCMAKE_FIND_ROOT_PATH=${PREFIX}" \
  "-DCMAKE_CXX_COMPILER=${NDK_TRIPLET}${API}-clang++" \
  "-DCMAKE_CC_COMPILER=${NDK_TRIPLET}${API}-clang" \
  "-DHAVE_LD_VERSION_SCRIPT=OFF"

ENV COMMON_AUTOCONF_FLAGS="--enable-static --disable-shared --prefix=${PREFIX} --host=${NDK_TRIPLET}${API}"

ENV NDK_BUILD_FLAGS \
    "NDK_PROJECT_PATH=." \
    "APP_BUILD_SCRIPT=./Android.mk" \
    "APP_PLATFORM=${API}" \
    "APP_ABI=${ABI}"

# Setup Python for Android
RUN cd ${HOME}/src/Python-3.13.4 && make clean && rm -rf Modules/_hacl/*.o Modules/_hacl/*.a
RUN cd ${HOME}/src/Python-3.13.4 && \
    ./configure \
  --host=aarch64-linux-android \
  --build=x86_64-linux-gnu \
  --prefix=/src/python-install \
  --enable-shared \
  --disable-ipv6 \
  --with-build-python=${HOME}/src/python-host-install/bin/python3.13 \
  ac_cv_file__dev_ptmx=no \
  ac_cv_file__dev_ptc=no && \
  make -j$(nproc)

# Setup rust build system for android
RUN wget https://sh.rustup.rs -O rustup.sh && sha256sum rustup.sh && \
    echo "17247e4bcacf6027ec2e11c79a72c494c9af69ac8d1abcc1b271fa4375a106c2  rustup.sh" | sha256sum -c - && \
    sh rustup.sh -y && rm rustup.sh && \
    ${HOME}/.cargo/bin/rustup target add ${NDK_TRIPLET} && \
    ${HOME}/.cargo/bin/rustup toolchain install nightly && \
    ${HOME}/.cargo/bin/rustup target add --toolchain nightly ${NDK_TRIPLET} && \
    echo "[target.${NDK_TRIPLET}]" >> /root/.cargo/config && \
    echo "linker = \"${TOOLCHAIN}/bin/${NDK_TRIPLET}${API}-clang\"" >> /root/.cargo/config

# Setup LIBICU
RUN mkdir -p ${HOME}/src/icu-${LIBICU_VERSION} && cd $_ && \
    ${HOME}/src/icu-release-${LIBICU_VERSION}/icu4c/source/configure \
        ${COMMON_AUTOCONF_FLAGS} \
        --disable-tests \
        --disable-samples \
        --disable-icuio \
        --disable-extras \
        --prefix=${PREFIX} \
        --with-cross-build=/root/src/icu-host-build && \
    make -j $(nproc) check_PROGRAMS= bin_PROGRAMS= && \
    make install check_PROGRAMS= bin_PROGRAMS=

# Setup Bzip2
RUN cd $HOME/src/ && git clone https://github.com/libarchive/bzip2 && cd bzip2 && \
    cmake . \
        $COMMON_CMAKE_ARGS && \
    make -j $(nproc) && make install

# Setup ZLIB
RUN wget -c https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
    mkdir -p ${HOME}/src/zlib-${ZLIB_VERSION}/build && cd $_ && \
    cmake ../ \
        ${COMMON_CMAKE_ARGS} && \
    make -j $(nproc) && make install

# Setup LIBJPEG_TURBO
RUN wget -c https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${LIBJPEG_TURBO_VERSION}/libjpeg-turbo-${LIBJPEG_TURBO_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
    mkdir -p ${HOME}/src/libjpeg-turbo-${LIBJPEG_TURBO_VERSION}/build && cd $_ && \
    cmake ../ \
        ${COMMON_CMAKE_ARGS} \
        -DENABLE_SHARED=false && \
    make -j $(nproc) && make install

# Setup LIBPNG
RUN wget -c http://prdownloads.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
    mkdir -p ${HOME}/src/libpng-${LIBPNG_VERSION}/build && cd $_ && \
        ${HOME}/src/libpng-${LIBPNG_VERSION}/configure \
        ${COMMON_AUTOCONF_FLAGS} && \
    make -j $(nproc) check_PROGRAMS= bin_PROGRAMS= && \
    make install check_PROGRAMS= bin_PROGRAMS=

# Setup FREETYPE2
RUN wget -c http://prdownloads.sourceforge.net/freetype/freetype-${FREETYPE2_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
    mkdir -p ${HOME}/src/freetype-${FREETYPE2_VERSION}/build && cd $_ && \
    cmake ../ \
        ${COMMON_CMAKE_ARGS} \
        -DCMAKE_DISABLE_FIND_PACKAGE_ZLIB=TRUE \
        -DCMAKE_DISABLE_FIND_PACKAGE_BZip2=TRUE \
        -DCMAKE_DISABLE_FIND_PACKAGE_PNG=TRUE && \
    make -j $(nproc) && make install

# Setup LIBXML
RUN wget -c https://github.com/GNOME/libxml2/archive/refs/tags/v${LIBXML2_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
    mkdir -p ${HOME}/src/libxml2-${LIBXML2_VERSION}/build && cd $_ && \
    cmake ../ \
        ${COMMON_CMAKE_ARGS} \
        -DBUILD_SHARED_LIBS=OFF \
        -DLIBXML2_WITH_THREADS=ON \
        -DLIBXML2_WITH_CATALOG=OFF \
        -DLIBXML2_WITH_ICONV=OFF \
        -DLIBXML2_WITH_LZMA=OFF \
        -DLIBXML2_WITH_PROGRAMS=OFF \
        -DLIBXML2_WITH_PYTHON=OFF \
        -DLIBXML2_WITH_TESTS=OFF \
        -DLIBXML2_WITH_ZLIB=ON && \
    make -j $(nproc) && make install

# Setup OBOE
RUN wget -c https://github.com/google/oboe/archive/refs/tags/${OBOE_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/

# Setup OPENAL
RUN wget -c https://github.com/kcat/openal-soft/archive/${OPENAL_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
    mkdir -p ${HOME}/src/openal-soft-${OPENAL_VERSION}/build && cd $_ && \
    cmake ../ \
        ${COMMON_CMAKE_ARGS} \
        -DALSOFT_EXAMPLES=OFF \
        -DALSOFT_TESTS=OFF \
        -DALSOFT_UTILS=OFF \
        -DALSOFT_NO_CONFIG_UTIL=ON \
        -DALSOFT_BACKEND_OPENSL=OFF \
        -DALSOFT_BACKEND_OBOE=ON \
        -DOBOE_SOURCE=${HOME}/src/oboe-${OBOE_VERSION} \
        -DALSOFT_BACKEND_WAVE=OFF && \
    make -j $(nproc) && make install

# Setup FFMPEG_VERSION
RUN wget -c http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2 -O - | tar -xjf - -C ${HOME}/src/ && \
    mkdir -p ${HOME}/src/ffmpeg-${FFMPEG_VERSION} && cd $_ && \
    ${HOME}/src/ffmpeg-${FFMPEG_VERSION}/configure \
        --disable-asm \
        --disable-optimizations \
        --target-os=android \
        --enable-cross-compile \
        --cross-prefix=${TOOLCHAIN}/bin/llvm- \
        --cc=${NDK_TRIPLET}${API}-clang \
        --arch=arm64 \
        --cpu=armv8-a \
        --prefix=${PREFIX} \
        --enable-version3 \
        --enable-pic \
        --disable-everything \
        --disable-doc \
        --disable-programs \
        --disable-autodetect \
        --disable-iconv \
        --enable-decoder=mp3 \
        --enable-demuxer=mp3 \
        --enable-decoder=bink \
        --enable-decoder=binkaudio_rdft \
        --enable-decoder=binkaudio_dct \
        --enable-demuxer=bink \
        --enable-demuxer=wav \
        --enable-decoder=pcm_* \
        --enable-decoder=vp8 \
        --enable-decoder=vp9 \
        --enable-decoder=opus \
        --enable-decoder=vorbis \
        --enable-demuxer=matroska \
        --enable-demuxer=ogg && \
    make -j $(nproc) && make install

# Setup SDL2_VERSION
RUN wget -c https://github.com/libsdl-org/SDL/releases/download/release-${SDL2_VERSION}/SDL2-${SDL2_VERSION}.tar.gz -O - | tar -xz -C ${HOME}/src/ && \
    mkdir -p ${HOME}/src/SDL2-${SDL2_VERSION}/build && cd $_ && \
    cmake ../ ${COMMON_CMAKE_ARGS} \
        -DSDL_STATIC=OFF \
        -DCMAKE_C_FLAGS=-DHAVE_GCC_FVISIBILITY=OFF\ "${CFLAGS}" && \
    make -j $(nproc) && make install
RUN cp -rf ${HOME}/src/SDL2-${SDL2_VERSION}/include/* /root/prefix/include/

# Setup BULLET
RUN wget -c https://github.com/bulletphysics/bullet3/archive/${BULLET_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
    mkdir -p ${HOME}/src/bullet3-${BULLET_VERSION}/build && cd $_ && \
    cmake ../ \
        ${COMMON_CMAKE_ARGS} \
        -DBUILD_BULLET2_DEMOS=OFF \
        -DBUILD_CPU_DEMOS=OFF \
        -DBUILD_UNIT_TESTS=OFF \
        -DBUILD_EXTRAS=OFF \
        -DUSE_DOUBLE_PRECISION=ON \
        -DBULLET2_MULTITHREADING=ON && \
    make -j $(nproc) && make install

# Setup GL4ES_VERSION
RUN wget -c https://github.com/Duron27/NG-GL4ES/archive/${GL4ES_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/
RUN mkdir -p ${HOME}/src/NG-GL4ES-${GL4ES_VERSION}/build && cd $_ && \
    cmake ../ ${COMMON_CMAKE_ARGS} && \
    make -j $(nproc) && cp -r ${HOME}/src/NG-GL4ES-${GL4ES_VERSION}/libraries/arm64-v8a/*.so ${PREFIX}/lib/ &&\
    cp -r ${HOME}/src/NG-GL4ES-${GL4ES_VERSION}/build/*.so ${PREFIX}/lib/ && \
    cp -r /root/src/NG-GL4ES-${GL4ES_VERSION}/include /root/prefix/ && \
    cp -r /root/src/NG-GL4ES-${GL4ES_VERSION}/include /root/prefix/include/gl4es

# Setup MYGUI
RUN wget -c https://github.com/MyGUI/mygui/archive/MyGUI${MYGUI_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
    mkdir -p ${HOME}/src/mygui-MyGUI${MYGUI_VERSION}/build && cd $_ && \
    cmake ../ \
        ${COMMON_CMAKE_ARGS} \
        -DMYGUI_RENDERSYSTEM=1 \
        -DMYGUI_BUILD_DEMOS=OFF \
        -DMYGUI_BUILD_TOOLS=OFF \
        -DMYGUI_BUILD_PLUGINS=OFF \
        -DMYGUI_DONT_USE_OBSOLETE=ON \
        -DMYGUI_STATIC=ON && \
    make -j $(nproc) && make install

# Setup LZ4
RUN wget -c https://github.com/lz4/lz4/archive/v${LZ4_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
    mkdir -p ${HOME}/src/lz4-${LZ4_VERSION}/build && cd $_ && \
    cmake cmake/ \
        ${COMMON_CMAKE_ARGS} \
        -DBUILD_STATIC_LIBS=ON \
        -DBUILD_SHARED_LIBS=OFF && \
    make -j $(nproc) && make install

# Setup LUAJIT_VERSION
RUN wget -c https://github.com/luaJit/LuaJIT/archive/v${LUAJIT_VERSION}.tar.gz -O - | tar -xz -C ${HOME}/src/ && \
    cd ${HOME}/src/LuaJIT-${LUAJIT_VERSION} && \
    make amalg \
    HOST_CC='gcc -m64' \
    CFLAGS= \
    TARGET_CFLAGS="${CFLAGS}" \
    PREFIX=${PREFIX} \
    CROSS=${TOOLCHAIN}/bin/llvm- \
    STATIC_CC=${NDK_TRIPLET}${API}-clang \
    DYNAMIC_CC="${NDK_TRIPLET}${API}-clang -fPIC" \
    TARGET_LD=${NDK_TRIPLET}${API}-clang && \
    make install \
    HOST_CC='gcc -m64' \
    CFLAGS= \
    TARGET_CFLAGS="${CFLAGS}" \
    PREFIX=${PREFIX} \
    CROSS=${TOOLCHAIN}/bin/llvm- \
    STATIC_CC=${NDK_TRIPLET}${API}-clang \
    DYNAMIC_CC="${NDK_TRIPLET}${API}-clang -fPIC" \
    TARGET_LD=${NDK_TRIPLET}${API}-clang

RUN rm ${PREFIX}/lib/libluajit*.so*

# Begin Star Control 2 Port

# Setup Libogg
RUN wget -c https://github.com/xiph/ogg/releases/download/v1.3.5/libogg-1.3.5.tar.gz -O - | tar -xz -C ${HOME}/src/ && cd ${HOME}/src/libogg-1.3.5 && \
    mkdir -p ${HOME}/src/libogg-1.3.5/build && cd $_ && \
    cmake .. \
        ${COMMON_CMAKE_ARGS} && \
    make -j $(nproc) && make install

# Setup Vorbis
RUN wget -c https://github.com/xiph/vorbis/releases/download/v1.3.7/libvorbis-1.3.7.tar.gz -O - | tar -xz -C ${HOME}/src/ && cd ${HOME}/src/libvorbis-1.3.7 && \
    mkdir -p ${HOME}/src/libvorbis-1.3.7/build && cd $_ && \
    cmake .. \
        ${COMMON_CMAKE_ARGS} && \
    make -j $(nproc) && make install

# Setup SDL_image
RUN wget -c https://github.com/libsdl-org/SDL_image/releases/download/release-2.8.4/SDL2_image-2.8.4.tar.gz -O - | tar -xz -C ${HOME}/src/ && cd ${HOME}/src/SDL2_image-2.8.4 && \
    mkdir -p ${HOME}/src/SDL2_image-2.8.4/build && cd $_ && \
    cmake .. \
        ${COMMON_CMAKE_ARGS} && \
    make -j $(nproc) && make install


COPY --chmod=0755 uqm /root/src/uqm
RUN mkdir -p /root/src/uqm/build && cd $_ && \
    cmake ../ \
        ${COMMON_CMAKE_ARGS} && \
    make -j $(nproc)

RUN cp /root/src/uqm/build/libuqm.so /
# End Port


