set -o pipefail

export BUILDPACK_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )


buildpack_source_halcyon () {
	if [[ -d "${BUILDPACK_DIR}/lib/halcyon" ]]; then
		HALCYON_NO_SELF_UPDATE="${BUILDPACK_NO_SELF_UPDATE:-0}" \
			source "${BUILDPACK_DIR}/lib/halcyon/src.sh" || return 1
		return 0
	fi

	local url base_url branch
	url="${HALCYON_URL:-https://github.com/mietek/halcyon}"
	base_url="${url%#*}"
	branch="${url#*#}"
	if [[ "${branch}" == "${base_url}" ]]; then
		branch='master'
	fi

	echo -n '-----> Installing Halcyon...' >&2

	local commit_hash
	commit_hash=$(
		git clone -q "${base_url}" "${BUILDPACK_DIR}/lib/halcyon" &>'/dev/null' &&
		cd "${BUILDPACK_DIR}/lib/halcyon" &&
		git checkout -q "${branch}" &>'/dev/null' &&
		git log -n 1 --pretty='format:%h'
	) || return 1
	echo " done, ${commit_hash:0:7}" >&2

	HALCYON_NO_SELF_UPDATE=1 \
		source "${BUILDPACK_DIR}/lib/halcyon/src.sh" || return 1
}


if ! buildpack_source_halcyon; then
	echo '   *** ERROR: Cannot source Halcyon' >&2
fi


source "${BUILDPACK_DIR}/src/buildpack.sh"
source "${BUILDPACK_DIR}/src/help.sh"


buildpack_self_update () {
	if (( ${BUILDPACK_NO_SELF_UPDATE:-0} )); then
		return 0
	fi

	if [[ ! -d "${BUILDPACK_DIR}/.git" ]]; then
		return 1
	fi

	local url
	url="${BUILDPACK_URL:-https://github.com/mietek/haskell-on-heroku}"

	log_begin 'Self-updating buildpack...'

	local commit_hash
	if ! commit_hash=$( git_update_into "${url}" "${BUILDPACK_DIR}" ); then
		log_end 'error'
		return 1
	fi
	log_end "done, ${commit_hash:0:7}"

	BUILDPACK_NO_SELF_UPDATE=1 \
		source "${BUILDPACK_DIR}/src.sh" || return 1
}


if ! buildpack_self_update; then
	log_warning 'Cannot self-update buildpack'
fi
