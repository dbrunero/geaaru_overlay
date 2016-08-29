# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=5
inherit eutils user versionator systemd

DESCRIPTION="The Apache Cassandra database is the right choice when you need
scalability and high availability without compromising performance."
HOMEPAGE="http://cassandra.apache.org/"
SRC_URI="mirror://apache/cassandra/${PV}/apache-cassandra-${PV}-bin.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE="+systemd"

DEPEND="
	>=virtual/jdk-1.8
"
RDEPEND="${DEPEND}
"

S="${WORKDIR}/apache-cassandra-${PV}"
INSTALL_DIR="/opt/cassandra"

pkg_setup() {
	enewgroup cassandra
	enewuser cassandra -1 /bin/bash ${INSTALL_DIR} cassandra
}

src_prepare() {
	cd "${S}"
	find . \( -name \*.bat -or -name \*.exe \) -delete
	rm bin/stop-server

	# Remove cqlsh staff (present of csqsh package)
	rm -rf pylib bin/cqlsh*

	# Temporary remove sigar library. I will investigate if it is needed
	rm -rf lib/sigar-bin/
}

src_install() {
	insinto ${INSTALL_DIR}

	sed -e "s|cassandra_storagedir=\"\$CASSANDRA_HOME/data\"|cassandra_storagedir=\"/var/lib/cassandra/\"|g" \
		-i bin/cassandra.in.sh || die

	doins -r bin conf interface lib tools

	for i in bin/* ; do
		if [[ $i == *.in.sh ]]; then
			continue
		fi
		fperms 755 ${INSTALL_DIR}/${i}
		make_wrapper "$(basename ${i})" "${INSTALL_DIR}/${i}"
	done

	keepdir /var/lib/cassandra/
	fowners -R cassandra:cassandra ${INSTALL_DIR}
	fowners -R cassandra:cassandra /var/lib/cassandra

	insinto /etc/cassandra
	doins conf/*.{properties,yaml} || die "doins failed"

	if use systemd; then
		systemd_dounit "${FILESDIR}/cassandra.service"
	else
		newinitd "${FILESDIR}/cassandra-initd" cassandra
	fi

	echo "CONFIG_PROTECT=\"${INSTALL_DIR}/conf\"" > "${T}/25cassandra" || die
	doenvd "${T}/25cassandra"

	# Runtime dirs needed
	keepdir /var/log/cassandra/ /var/lib/cassandra/commitlog /var/lib/cassandra/data || die "keepdir failed"

}

pkg_postinst() {

	elog "Cassandra's configuration is at /etc/cassandra"
	elog "Cassandra works best when the commitlog directory and the data directory are on different disks"
	elog "The default configuration sets them to /var/lib/cassandra/commitlog and /var/lib/cassandra/data respectively"
	elog "You may wish to change those to different mount points"

	ewarn "You should start/stop cassandra via systemctl/initrd service, as this will properly switch to the cassandra:cassandra user group"
	ewarn "Starting cassandra via its default 'cassandra' shell command, as root, may cause permission problems later on when started as the cassandra user"

}
