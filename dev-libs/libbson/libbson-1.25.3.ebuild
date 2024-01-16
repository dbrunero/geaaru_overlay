# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3+ )
inherit cmake python-any-r1

DESCRIPTION="Library routines related to building,parsing and iterating BSON documents"
HOMEPAGE="https://github.com/mongodb/mongo-c-driver/tree/master/src/libbson"
SRC_URI="https://github.com/mongodb/mongo-c-driver/tarball/30ab91dd39ce4e7b42616f5aac1cc9b1b113d187 -> mongo-c-driver-1.25.1-30ab91d.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="*"
IUSE="examples static-libs"

DEPEND="dev-python/sphinx"

post_src_unpack() {
	if [ ! -d "${S}" ]; then
		mv "${WORKDIR}"/* "${S}" || die
	fi
}

src_prepare() {
	cmake_src_prepare

	# remove doc files
	sed -i '/^\s*install\s*(FILES COPYING NEWS/,/^\s*)/ {d}' CMakeLists.txt || die

	sed -i -e 's|${PROJECT_SOURCE_DIR}/src/bson/bcon.h|${PROJECT_SOURCE_DIR}/src/bson/bcon.h\n   $\{PROJECT_SOURCE_DIR\}/../common/bson-dsl.h|g' \
	src/libbson/CMakeLists.txt || die

	# It seems that the docs python script using py3.10 syntax but
	# the library works with py3.9 too.
	sed -i -e 's/str | None/str/g' build/sphinx/mongoc_common.py || die

	echo "#!/usr/bin/env python
print('${PV}')
" > build/calc_release_version.py
}

src_configure() {
	local mycmakeargs=(
		-DUSE_SYSTEM_LIBBSON=FALSE
		-DENABLE_EXAMPLES=OFF
		-DENABLE_MAN_PAGES=ON
		-DENABLE_MONGOC=OFF
		-DENABLE_TESTS=OFF
		-DENABLE_STATIC="$(usex static-libs ON OFF)"
		-DENABLE_UNINSTALL=OFF
	)

	python_setup
	cmake_src_configure
}

src_install() {
	if use examples; then
		docinto examples
		dodoc src/libbson/examples/*.c
	fi

	cmake_src_install
}
