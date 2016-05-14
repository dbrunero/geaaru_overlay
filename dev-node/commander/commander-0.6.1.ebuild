# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$
# Ebuild automatically produced by node-ebuilder.

EAPI=5

DESCRIPTION="the complete solution for node.js command-line programs"
HOMEPAGE="https://github.com/visionmedia/commander.js#readme"

SLOT="0"
KEYWORDS="~amd64 ~arm"
IUSE=""

DEPEND="
"
RDEPEND="${DEPEND}"

NPM_BINS="
"
NPM_NO_DEPS=1

S="${WORKDIR}/package"

inherit npmv1

