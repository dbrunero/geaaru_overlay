# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

#
# @ECLASS: npmv1.eclass
# @MAINTAINER:
# geaaru<at>gmail.com
# @AUTHOR:
# Geaaru geaaru<at>gmail.com
# @DESCRIPTION:
# Purpose: Manage installation of nodejs application with automatic
#          download of the modules defined on package.json file.

inherit multilib

# TODO:
#  * support multi slot ebuilds
#
# ECLASS VARIABLES:
#  * NPM_DEFAULT_OPTS:   Contains options used with npm program to download nodejs modules of
#                        the package. Default values are: "-E --no-optional --production"
#  * NPM_PKG_NAME:       Contains package name. Default value is ${PN}.
#  * NPM_PACKAGEDIR:     Contains default install directory of the package.
#                        Default value is: ${EROOT}usr/$(get_libdir)/node_modules/${NPM_PKG_NAME}/
#  * NPM_GITHUP_MOD:     For nodejs module available on github identify user and module for
#                        automatically create SRC_URI.
#  * NPM_BINS:           If defined contains list of file used as binaries. Syntax could be
#                        the simple file name of if binary must be renamed syntax could be like this:
#                        NPM_BINS="
#                            origin_bin => install_bins
#                        "
#                        NOTE: Every binary is installed under bin directory of NPM_PACKAGEDIR
#                              For binary under /usr/bin is created a bash script where is
#                              initialized NODE_PATH variable to use first ${NPM_PACKAGEDIR}/node_modules
#                              directory and then system node_modules directory.
#                        To avoid install of all binaries use NPM_BINS="".
#  * NPM_SYSTEM_MODULES: If defined permit to avoid install of the packages modules to insert
#                        on this variable. This permit to use module installed from another ebuild.
#  * NPM_PKG_DIRS:       Permit of defines additional directories to intall. Default install directory
#                        if available is lib directory.

_npmv1_set_metadata() {

    DEPEND="${DEPEND}
        net-libs/nodejs[npm(+)]
    "
    if [[ -z "${NPM_DEFAULT_OPTS}" ]] ; then
        NPM_DEFAULT_OPTS="-E --no-optional --production"
    fi
    if [[ -z "${NPM_PKG_NAME}" ]] ; then
        NPM_PKG_NAME="${PN}"
    fi
    if [[ -z "${NPM_PACKAGEDIR}" ]] ; then
        NPM_PACKAGEDIR="${EROOT}usr/$(get_libdir)/node_modules/${NPM_PKG_NAME}"
    fi
    if [[ -z "${SRC_URI}" ]] ; then
        if [[ -n "${NPM_GITHUP_MOD}" ]] ; then
            SRC_URI="https://github.com/${NPM_GITHUP_MOD}/archive/v${PV}.zip"
        else
            SRC_URI="http://registry.npmjs.org/${PN}/-/${PF}.tgz"
        fi
    fi

}

_npmv1_set_metadata
unset -f _npmv1_set_metadata

EXPORT_FUNCTIONS src_prepare src_compile src_install

# @FUNCTION: npmv1_src_prepare
# @DESCRIPTION:
# Implementation of src_prepare() phase. This function is exported.
npmv1_src_prepare() {

    # I'm on ${S}

    # Check if present package.json
    test -f package.json || die "package.json not found in package ${PN}"

}

# @FUNCTION: npmv1_src_configure
# @DESCRIPTION:
# Implementation of src_compile() phase. This function is exported.
npmv1_src_compile() {

    npm ${NPM_DEFAULT_OPTS} install || die "Error on download node modules!"

}

# @FUNCTION: npmv1_src_install
# @DESCRIPTION:
# Implementation of src_compile() phase. This function is exported.
npmv1_src_install() {

    local words=""
    local sym=""
    local i=0
    local npm_root_js_files=""
    local npm_pkg_mods=""
    local npm_sys_mods=""

    _npmv1_create_bin_script () {

        local binfile=$1
        local bindir="$2"
        local scriptname="$3"

        if [[ ! -e ${ED}usr/bin ]] ; then
            mkdir -p ${ED}usr/bin
        fi

        echo \
"#!/bin/bash
# Author: geaaru@gmail.com
# Description: Autogenerated script from npmv1 eclass for package ${PN}.

def_node_path="${EROOT}usr/$(get_libdir)/node_modules/"
app_node_path="${NPM_PACKAGEDIR}/node_modules/"

export NODE_PATH=\${app_node_path}:\${def_node_path}

${bindir}/${binfile} \$@
" >     ${ED}/usr/bin/${scriptname} || return 1

        chmod a+x ${ED}/usr/bin/${scriptname} || return 1

        return 0
    }

    _npmv1_install_module () {

        local mod=$1
        local mod2install=true
        local i=0
        local sym=""
        local words=""
        local f=""

        # Check if present on system module
        for i in ${!npm_sys_mods[@]} ; do
            if [[ ${mod} = ${npm_sys_mods[$i]} ]] ; then
                mod2install=false
                break
            fi
        done

        if [[ $mod2install = true ]] ; then
            cp -rf node_modules/${mod} ${D}/${NPM_PACKAGEDIR}/node_modules/ || \
                die "Error on install module ${mod}."
        fi

        return 0
    }

    _npmv1_copy_root_js_files () {

        local i=0
        if [[ ${#npm_root_js_files[@]} -gt 0 ]] ; then

            for i in ${!npm_root_js_files[@]} ; do
                into ${NPM_PACKAGEDIR}
                doins ${npm_root_js_files[$i]} || \
                    die "Error on install file ${npm_root_js_files[$i]}"
            done # end for i ..
        fi
    }

    _npmv1_copy_dirs() {

        local i=0
        local npm_other_dirs=( ${NPM_PKG_DIRS} )

        if [[ ${#npm_other_dirs[@]} -gt 0 ]] ; then

            for i in ${!npm_other_dirs[@]} ; do
                cp -rf ${npm_other_dirs[$i]} ${D}/${NPM_PACKAGEDIR} || \
                    die "Error on copy directory ${npm_other_dirs[$i]}!"
            done # end for i ..
        fi
    }

    if [ -n "${NPM_BINS}" ] ; then

        # Install only defined binaries

        while read line ; do
            words=$(c() { echo $#; }; c $line)
            sym=""
            f=""

            if [ ${#line} -gt 1 ] ; then
                if [[ $line =~ .*\=\>.* ]] ; then
                    # With rename
                    [ ${#words[@]} -lt 3 ] && \
                        die "Invalid binary row $line."
                    sym=${words[2]}
                    f=${words[0]}
                else
                    # Without rename
                    [ ${#words[@]} -gt 1 ] && \
                        die "Invalid binary row $line."
                    sym=${line}
                    f=${line}

                fi
            fi

            if [[ x"${f}" = x ]] ; then
                # Handle NPM_BINS empty for avoid install
                # of binaries files
                continue
            fi

            if [ -f ${S}/bin/${f} ] ; then
                exeinto ${NPM_PACKAGEDIR}/bin/
                doexe ${S}/bin/${f} || die "Error on install $f."
                _npmv1_create_bin_script "${f}" "${NPM_PACKAGEDIR}/bin" "${sym}" || \
                    die "Error on create binary script for ${f}."
            else
                if [ -f ${S}/${f} ] ; then
                    exeinto ${NPM_PACKAGEDIR}/
                    doexe ${S}/${f} || die "Error on install $f."
                    _npmv1_create_bin_script "${f}" "${NPM_PACKAGEDIR}" "${sym}" || \
                        die "Error on create binary script for ${f}."
                else
                    die "Binary ${f} is not present."
                fi
            fi # end if [ -e ${S}/bin/${f}

        done <<<"${NPM_BINS}"

    else

        for f in ${S}/bin/* ; do
            local fname=$(basename ${f})

            if [ -e ${f} ] ; then
                exeinto ${NPM_PACKAGEDIR}/bin/
                doexe ${f} || die "Error on install $f."
                _npmv1_create_bin_script "${fname}" "${NPM_PACKAGEDIR}/bin" "${fname}" || \
                    die "Error on create binary script for ${fname}."
            fi
        done # end for

    fi

    insinto ${NPM_PACKAGEDIR}
    doins package.json

    # Store list of package modules on npm_pkg_mods array
    npm_pkg_mods=( $(ls --color=none node_modules/) )

    if [[ -n "${NPM_SYSTEM_MODULES}" ]] ; then

        # Install package modules
        dodir ${NPM_PACKAGEDIR}/node_modules/

        # Create an array with all modules to exclude from copy
        npm_sys_mods=( ${NPM_SYSTEM_MODULES} )

        for i in ${!npm_pkg_mods[@]} ; do
            _npmv1_install_module "${npm_pkg_mods[$i]}"
        done

    else
        if [[ ${#npm_pkg_mods[@]} -gt 0 ]] ; then
            # Install package modules
            dodir ${NPM_PACKAGEDIR}/node_modules/

            cp -rf node_modules/* ${D}/${NPM_PACKAGEDIR}/node_modules/
        fi
    fi

    # Copy all .js from root directory
    npm_root_js_files=( $(ls --color=none . | grep --color=none "\.js$") )
    _npmv1_copy_root_js_files

    # Copy library directory
    if [[ -d lib ]] ; then
        cp -rf lib ${D}/${NPM_PACKAGEDIR} || die "Error on copy directory lib!"
    fi

    # Check if are present additional directories to copy
    if [[ -n "${NPM_PKG_DIRS}" ]] ; then
        _npmv1_copy_dirs
    fi

    for f in ChangeLog CHANGELOG.md LICENSE LICENSE.txt REAME README.md ; do
        [[ -e ${f} ]] && dodoc ${f}
    done # end for

    unset -f _npmv1_create_bin_script
    unset -f _npmv1_install_module
    unset -f _npmv1_copy_root_js_files
    unset -f _npmv1_copy_dirs

}

# vim: ts=4 sw=4 expandtab
