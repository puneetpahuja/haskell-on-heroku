set -o pipefail

export BUILDPACK_TOP_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )


buildpack_source_halcyon () {
	if [[ -d "${BUILDPACK_TOP_DIR}/lib/halcyon" ]]; then
		HALCYON_NO_AUTOUPDATE="${BUILDPACK_NO_AUTOUPDATE:-0}" \
			source "${BUILDPACK_TOP_DIR}/lib/halcyon/src.sh" || return 1
		return 0
	fi

	local url bare_url branch
	url="${HALCYON_URL:-https://github.com/mietek/halcyon}"
	bare_url="${url%#*}"
	branch="${url#*#}"
	if [[ "${branch}" == "${bare_url}" ]]; then
		branch='master'
	fi

	echo -n '-----> Installing Halcyon...' >&2

	local commit_hash
	commit_hash=$(
		git clone -q "${bare_url}" "${BUILDPACK_TOP_DIR}/lib/halcyon" &>'/dev/null' &&
		cd "${BUILDPACK_TOP_DIR}/lib/halcyon" &&
		git checkout -q "${branch}" &>'/dev/null' &&
		git log -n 1 --pretty='format:%h'
	) || return 1
	echo " done, ${commit_hash:0:7}" >&2

	HALCYON_NO_AUTOUPDATE=1 \
		source "${BUILDPACK_TOP_DIR}/lib/halcyon/src.sh" || return 1
}


if ! buildpack_source_halcyon; then
	echo '   *** ERROR: Cannot source Halcyon' >&2
fi


source "${BUILDPACK_TOP_DIR}/src/buildpack.sh"
source "${BUILDPACK_TOP_DIR}/src/help.sh"


buildpack_autoupdate () {
	if (( ${BUILDPACK_NO_AUTOUPDATE:-0} )); then
		return 0
	fi

	if [[ ! -d "${BUILDPACK_TOP_DIR}/.git" ]]; then
		return 1
	fi

	local url
	url="${BUILDPACK_URL:-https://github.com/mietek/haskell-on-heroku}"

	log_begin 'Auto-updating buildpack...'

	local commit_hash
	commit_hash=$( git_update_into "${url}" "${BUILDPACK_TOP_DIR}" ) || return 1
	log_end "done, ${commit_hash:0:7}"

	BUILDPACK_NO_AUTOUPDATE=1 \
		source "${BUILDPACK_TOP_DIR}/src.sh" || return 1
}


if ! buildpack_autoupdate; then
	log_warning 'Cannot auto-update buildpack'
fi
