# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3+ )

inherit cmake python-single-r1 toolchain-funcs

DESCRIPTION="Video editing library used by OpenShot"
HOMEPAGE="https://www.openshot.org/"
SRC_URI="https://github.com/OpenShot/libopenshot/tarball/3170768e0ccbaad5b2a4696e84dd649738ec1a1b -> libopenshot-0.3.3-3170768.tar.gz"

LICENSE="GPL-3+"
SLOT="0/21"
KEYWORDS="*"
IUSE="doc examples +imagemagick +opencv +python"

REQUIRED_USE="python? ( ${PYTHON_REQUIRED_USE} )"

RDEPEND="dev-libs/jsoncpp:0=
	dev-libs/protobuf:=
	dev-qt/qtcore:5
	dev-qt/qtgui:5
	dev-qt/qtmultimedia:5[widgets]
	>=media-libs/libopenshot-audio-0.2.1:0=
	media-video/ffmpeg:0=[encode,x264,xvid,vpx,mp3,theora,vorbis]
	net-libs/cppzmq
	net-libs/zeromq
	imagemagick? ( >=media-gfx/imagemagick-7:0=[cxx] )
	opencv? ( >=media-libs/opencv-4.5.2:=[contrib] )
	python? ( ${PYTHON_DEPS} )"
DEPEND="${RDEPEND}"
BDEPEND="doc? ( app-doc/doxygen )
	python? ( dev-lang/swig )
	"

post_src_unpack() {
	mv OpenShot-${PN}-* "${S}"
}

pkg_pretend() {
	[[ ${MERGE_TYPE} != binary ]] && tc-check-openmp
}

pkg_setup() {
	[[ ${MERGE_TYPE} != binary ]] && tc-check-openmp
	use python && python-single-r1_pkg_setup
}

src_prepare() {
	cmake_src_prepare
	# https://github.com/OpenShot/libopenshot/issues/17
	cmake_comment_add_subdirectory tests
}

src_configure() {
	local mycmakeargs=(
		-DDISABLE_BUNDLED_JSONCPP=ON
		-DENABLE_MAGICK=$(usex imagemagick)
		-DENABLE_OPENCV=$(usex opencv)
		-DENABLE_RUBY=OFF # TODO: add ruby support
		-DENABLE_PYTHON=$(usex python)
		-DENABLE_TESTS=false
		-DUSE_SYSTEM_JSONCPP=ON
		$(cmake_use_find_package imagemagick ImageMagick)
	)
	use python && mycmakeargs+=(
		-DPYTHON_EXECUTABLE="${PYTHON}"
		-DPYTHON_INCLUDE_DIR="$(python_get_includedir)"
		-DPYTHON_LIBRARY="$(python_get_library_path)"
	)
	cmake_src_configure
}

src_compile() {
	cmake_src_compile
	use doc && cmake_build doc
}

src_install() {
	local DOCS=( AUTHORS README.md doc/HW-ACCEL.md )
	use examples && DOCS+=( examples/ )
	use doc && local HTML_DOCS=( "${BUILD_DIR}"/doc/html/. )

	cmake_src_install
	use python && python_optimize
}