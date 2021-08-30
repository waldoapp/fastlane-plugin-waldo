#!/usr/bin/env bash

set -eu -o pipefail

waldo_api_build_endpoint=${WALDO_API_BUILD_ENDPOINT:-https://api.waldo.io/versions}
waldo_api_error_endpoint=${WALDO_API_ERROR_ENDPOINT:-https://api.waldo.io/uploadError}
waldo_api_symbols_endpoint=${WALDO_API_SYMBOLS_ENDPOINT:-https://api.waldo.io/versions/__ID__/symbols}
waldo_user_agent_override=${WALDO_USER_AGENT_OVERRIDE:-}

waldo_cli_version="1.6.6"

waldo_build_flavor=""
waldo_build_path=""
waldo_build_payload_path=""
waldo_build_suffix=""
waldo_build_upload_id=""
waldo_extra_args="--show-error --silent"
waldo_history=""
waldo_history_error=""
waldo_include_symbols=false
waldo_platform=""
waldo_symbols_path=""
waldo_symbols_payload_path=""
waldo_symbols_suffix=""
waldo_upload_token=""
waldo_variant_name=""
waldo_working_path=""

function abs_path() {
    local _rel_path=$1

    [[ -n $_rel_path ]] || _rel_path="."

    case "$_rel_path" in
        .)  pwd ;;
        ..) (unset CDPATH && cd .. &>/dev/null && pwd) ;;
        /*) echo $_rel_path ;;
        *)  local _dirname=$(dirname "$_rel_path")

            _dirname=$(unset CDPATH && cd "$_dirname" &>/dev/null && pwd)

            if [[ -n $_dirname ]]; then
                echo ${_dirname}/$(basename "$_rel_path")
            else
                echo $_rel_path
            fi
            ;;
    esac
}

function check_build_path() {
    [[ -n $waldo_build_path ]] || fail_usage "Missing required argument: ‘path’"

    waldo_build_path=$(abs_path "$waldo_build_path")
    waldo_build_suffix=${waldo_build_path##*.}

    case $waldo_build_suffix in
        apk)     waldo_build_flavor="Android" ;;
        app|ipa) waldo_build_flavor="iOS" ;;
        *)       fail "File extension of build at ‘${waldo_build_path}’ is not recognized" ;;
    esac
}

function check_build_status() {
    local _response=$1

    local _status_regex='"status":([0-9]+)'

    if [[ $_response =~ $_status_regex ]]; then
        local _status=${BASH_REMATCH[1]}

        if (( $_status == 401 )); then
            fail "Upload token is invalid or missing!"
        elif (( $_status < 200 || $_status > 299 )); then
            fail "Unable to upload build to Waldo, HTTP status: $_status"
        fi
    fi

    local _id_regex='"id":"(appv-[0-9a-f]+)"'

    if [[ $_response =~ $_id_regex ]]; then
        waldo_build_upload_id=${BASH_REMATCH[1]}
    fi
}

function check_history() {
    if [[ -z $(which base64) ]]; then
        waldo_history_error="noBase64CommandFound"
    elif [[ -z $(which git) ]]; then
        waldo_history_error="noGitCommandFound"
    elif [[ -z $(which grep) ]]; then
        waldo_history_error="noGrepCommandFound"
    elif [[ -z $(which sed) ]]; then
        waldo_history_error="noSedCommandFound"
    elif [[ -z $(which tr) ]]; then
        waldo_history_error="noTrCommandFound"
    elif ! git rev-parse >& /dev/null; then
        waldo_history_error="notGitRepository"
    else
        waldo_history=$(get_history)
    fi
}

function check_platform() {
    if [[ -z $(which curl) ]]; then
        fail "No ‘curl’ command found"
    fi
}

function check_symbols_path() {
    case $waldo_build_suffix in
        app)
            if [[ -z $waldo_symbols_path && $waldo_include_symbols == true ]]; then
                waldo_symbols_path=$(find_symbols_path)
            fi
            ;;
        ipa) ;;
        *) waldo_symbols_path="" ;; # not applicable
    esac

    [[ -n $waldo_symbols_path ]] || return 0

    waldo_symbols_path=$(abs_path "$waldo_symbols_path")
    waldo_symbols_suffix=${waldo_symbols_path##*.}

    case $waldo_symbols_suffix in
        dSYM|xcarchive|zip) ;;  # OK
        *)                  fail "File extension of symbols at ‘${waldo_symbols_path}’ is not recognized" ;;
    esac
}

function check_symbols_status() {
    local _response=$1

    local _status_regex='"status":([0-9]+)'

    if [[ $_response =~ $_status_regex ]]; then
        local _status=${BASH_REMATCH[1]}

        if (( $_status == 401 )); then
            fail "Upload token is invalid or missing!"
        elif (( $_status < 200 || $_status > 299 )); then
            fail "Unable to upload symbols to Waldo, HTTP status: $_status"
        fi
    fi
}

function check_upload_token() {
    [[ -n $waldo_upload_token ]] || waldo_upload_token=${WALDO_UPLOAD_TOKEN:-}
    [[ -n $waldo_upload_token ]] || fail_usage "Missing required option: ‘--upload_token’"
}

function check_variant_name() {
    [[ -n $waldo_variant_name ]] || waldo_variant_name=${WALDO_VARIANT_NAME:-}
}

function convert_sha() {
    local _full_sha=$1
    local _full_name=$(git name-rev --refs='heads/*' --name-only "$_full_sha")
    local _abbr_sha=${_full_sha:0:7}
    local _abbr_name=$_full_name
    local _prefix="remotes/origin/"

    if [[ ${_full_name:0:${#_prefix}} == $_prefix ]]; then
        _abbr_name=${_full_name#$_prefix}
    else
        _abbr_name="local:${_full_name}"
    fi

    echo "${_abbr_sha}-${_abbr_name}"
}

function convert_shas() {
    local _list=

    while (( $# )); do
        local _item=$(convert_sha "$1")

        _list+=",\"${_item}\""

        shift
    done

    echo ${_list#?}
}

function create_build_payload() {
    local _parent_path=$(dirname "$waldo_build_path")
    local _build_name=$(basename "$waldo_build_path")

    case $waldo_build_suffix in
        app)
            ([[ -d $waldo_build_path && -r $waldo_build_path ]])  \
                || fail "Unable to read build at ‘${waldo_build_path}’"

            if [[ -z $(which zip) ]]; then
                fail "No ‘zip’ command found"
            fi

            waldo_build_payload_path="$waldo_working_path"/"$_build_name".zip

            (cd "$_parent_path" &>/dev/null && zip -qry "$waldo_build_payload_path" "$_build_name") || return
            ;;

        *)
            ([[ -f $waldo_build_path && -r $waldo_build_path ]])  \
                || fail "Unable to read build at ‘${waldo_build_path}’"

            waldo_build_payload_path=$waldo_build_path
            ;;
    esac
}

function create_symbols_payload() {
    [[ -n $waldo_symbols_path ]] || return 0

    local _parent_path=$(dirname "$waldo_symbols_path")
    local _symbols_name=$(basename "$waldo_symbols_path")

    case $waldo_symbols_suffix in
        dSYM)
            ([[ -d $waldo_symbols_path && -r $waldo_symbols_path ]])  \
                || fail "Unable to read symbols at ‘${waldo_symbols_path}’"

            if [[ -z $(which zip) ]]; then
                fail "No ‘zip’ command found"
            fi

            waldo_symbols_payload_path="$waldo_working_path"/"$_symbols_name".zip

            (cd "$_parent_path" &>/dev/null && zip -qry "$waldo_symbols_payload_path" "$_symbols_name") || return
            ;;

        xcarchive)
            ([[ -d $waldo_symbols_path && -r $waldo_symbols_path ]])  \
                || fail "Unable to read symbols at ‘${waldo_symbols_path}’"

            if [[ -z $(which zip) ]]; then
                fail "No ‘zip’ command found"
            fi

            local _tmp_symbols_path="$waldo_working_path"/"$_symbols_name"

            mkdir -p "$_tmp_symbols_path"

            cp -r "$waldo_symbols_path"/BCSymbolMaps "$_tmp_symbols_path"
            cp -r "$waldo_symbols_path"/dSYMs "$_tmp_symbols_path"

            waldo_symbols_payload_path="$_tmp_symbols_path".zip

            (cd "$waldo_working_path" &>/dev/null && zip -qry "$waldo_symbols_payload_path" "$_symbols_name") || return
            ;;

        *)
            ([[ -f $waldo_symbols_path && -r $waldo_symbols_path ]])  \
                || fail "Unable to read symbols at ‘${waldo_symbols_path}’"

            waldo_symbols_payload_path=$waldo_symbols_path
            ;;
    esac
}

function create_working_path() {
    waldo_working_path=/tmp/WaldoCLI-$$

    rm -rf "$waldo_working_path"
    mkdir -p "$waldo_working_path"
}

function curl_upload_build() {
    local _output_path="$1"
    local _authorization=$(get_authorization)
    local _content_type=$(get_build_content_type)
    local _user_agent=$(get_user_agent)
    local _url=$(make_build_url)

    curl $waldo_extra_args                          \
        --data-binary @"$waldo_build_payload_path"  \
        --header "Authorization: $_authorization"   \
        --header "Content-Type: $_content_type"     \
        --header "User-Agent: $_user_agent"         \
        --output "$_output_path"                    \
        "$_url"

    local _curl_status=$?

    if (( $_curl_status != 0 )); then
        fail "Unable to upload build to Waldo, curl error: ${_curl_status}, url: ${_url}"
    fi
}

function curl_upload_error() {
    local _message=$(json_escape "$1")
    local _ci=$(get_ci)
    local _authorization=$(get_authorization)
    local _content_type=$(get_error_content_type)
    local _user_agent=$(get_user_agent)
    local _url=$(make_error_url)

    curl --silent                                                   \
        --data "{\"message\":\"${_message}\",\"ci\":\"${_ci}\"}"    \
        --header "Authorization: $_authorization"                   \
        --header "Content-Type: $_content_type"                     \
        --header "User-Agent: $_user_agent"                         \
        "$_url" &>/dev/null
}

function curl_upload_symbols() {
    local _output_path="$1"
    local _authorization=$(get_authorization)
    local _content_type=$(get_symbols_content_type)
    local _user_agent=$(get_user_agent)
    local _url=$(make_symbols_url)

    curl $waldo_extra_args                              \
        --data-binary @"$waldo_symbols_payload_path"    \
        --header "Authorization: $_authorization"       \
        --header "Content-Type: $_content_type"         \
        --header "User-Agent: $_user_agent"             \
        --output "$_output_path"                        \
        "$_url"

    local _curl_status=$?

    if (( $_curl_status != 0 )); then
        fail "Unable to upload symbols to Waldo, curl error: ${_curl_status}, url: ${_url}"
    fi
}

function delete_working_path() {
    if [[ -n $waldo_working_path ]]; then
        rm -rf "$waldo_working_path"
    fi
}

function display_summary() {
    echo ""
    echo "Build path:   $(summarize "$waldo_build_path")"
    echo "Symbols path: $(summarize "$waldo_symbols_path")"
    echo "Variant name: $(summarize "$waldo_variant_name")"
    echo "Upload token: $(summarize_secure "$waldo_upload_token")"
    echo ""

    if [[ $waldo_extra_args == "--verbose" ]]; then
        echo "Build payload path:   $(summarize "$waldo_build_payload_path")"
        echo "Symbols payload path: $(summarize "$waldo_symbols_payload_path")"
        echo ""
    fi
}

function display_usage() {
    cat <<EOF

OVERVIEW: Upload build to Waldo

USAGE: waldo [options] <build-path> [<symbols-path>]

OPTIONS:

  --help                  Display available options
  --include_symbols       Include symbols with the build upload
  --upload_token <value>  Waldo upload token (overrides WALDO_UPLOAD_TOKEN)
  --variant_name <value>  Waldo variant name (overrides WALDO_VARIANT_NAME)
  --verbose               Display extra verbiage
EOF
}

function display_version() {
    waldo_platform=$(get_platform)

    echo "Waldo CLI $waldo_cli_version ($waldo_platform)"
}

function fail() {
    local _message="waldo: $1"

    if [[ -n $waldo_upload_token ]]; then
        curl_upload_error "$1"

        local _curl_status=$?

        if (( $_curl_status == 0)); then
            _message+=" -- Waldo team has been informed"
        fi
    fi

    echo ""                 # flush stdout
    echo "$_message" 1>&2
    exit 1
}

function fail_usage() {
    [[ -z $waldo_upload_token ]] || curl_upload_error "$1"

    echo ""                 # flush stdout
    echo "waldo: $1" 1>&2
    display_usage
    exit 1
}

function find_symbols_path() {
    if [[ -e ${waldo_build_path}.dSYM.zip ]]; then
        echo "${waldo_build_path}.dSYM.zip"
    elif [[ -e ${waldo_build_path}.dSYM ]]; then
        echo "${waldo_build_path}.dSYM"
    fi
}

function get_authorization() {
    echo "Upload-Token $waldo_upload_token"
}

function get_build_content_type() {
    case $waldo_build_suffix in
        app) echo "application/zip" ;;
        *)   echo "application/octet-stream" ;;
    esac
}

function get_ci() {
    if [[ -n ${APPCENTER_BUILD_ID:-} ]]; then
        echo "App Center"
    elif [[ ${BITRISE_IO:-false} == true ]]; then
        echo "Bitrise"
    elif [[ -n ${BUDDYBUILD_BUILD_ID:-} ]]; then
        echo "buddybuild"
    elif [[ ${CIRCLECI:-false} == true ]]; then
        echo "CircleCI"
    elif [[ ${GITHUB_ACTIONS:-false} == true ]]; then
        echo "GitHub Actions"
    elif [[ ${TRAVIS:-false} == true ]]; then
        echo "Travis CI"
    else
        echo "CLI"
    fi
}

function get_error_content_type() {
    echo "application/json"
}

function get_history() {
    local _shas=$(git log --format='%H' --skip=$(get_skip_count) -50)
    local _history=$(convert_shas $_shas)

    echo "[${_history}]" | websafe_base64_encode
}

function get_platform() {
    local _os_name=$(uname -s)

    case $_os_name in
        Darwin) echo "macOS" ;;
        *)      echo "$_os_name" ;;
    esac
}

function get_skip_count() {
    if [[ ${GITHUB_ACTIONS:-false} == true && ${GITHUB_EVENT_NAME:-} == "pull_request" ]]; then
        echo "1"
    else
        echo "0"
    fi
}

function get_symbols_content_type() {
    echo "application/zip"
}

function get_user_agent() {
    if [[ -n $waldo_user_agent_override ]]; then
        echo "$waldo_user_agent_override"
    else
        echo "Waldo $(get_ci)/${waldo_build_flavor} v${waldo_cli_version}"
    fi
}

function json_escape() {
    local _result=${1//\\/\\\\} # \

    _result=${_result//\//\\\/} # /
    _result=${_result//\'/\\\'} # '
    _result=${_result//\"/\\\"} # "

    echo "$_result"
}

function make_build_url() {
    local _query=

    if [[ -n $waldo_history ]]; then
        _query+="&history=$waldo_history"
    fi

    if [[ -n $waldo_history_error ]]; then
        _query+="&historyError=$waldo_history_error"
    fi

    if [[ -n $waldo_variant_name ]]; then
        _query+="&variantName=$waldo_variant_name"
    fi

    if [[ -n $_query ]]; then
        echo "${waldo_api_build_endpoint}?${_query:1}"
    else
        echo "${waldo_api_build_endpoint}"
    fi
}

function make_error_url() {
    echo "${waldo_api_error_endpoint}"
}

function make_symbols_url() {
    echo "${waldo_api_symbols_endpoint/__ID__/$waldo_build_upload_id}"
}

function summarize() {
    local _value=$1

    if [[ -n $_value ]]; then
        echo "‘${_value}’"
    else
        echo "(none)"
    fi
}

function summarize_secure() {
    local _value=$1

    if [[ $waldo_extra_args != "--verbose" ]]; then
        local _prefix=${_value:0:6}
        local _suffix_len=$(( ${#_value} - ${#_prefix} ))
        local _secure='********************************'

        _value="${_prefix}${_secure:0:$_suffix_len}"
    fi

    summarize "$_value"
}

function upload_build() {
    local _build_name=$(basename "$waldo_build_path")

    local _response_path=$waldo_working_path/build_response.json

    echo "Uploading build to Waldo"

    [[ $waldo_extra_args == "--verbose" ]] && echo ""

    curl_upload_build "$_response_path"

    local _curl_status=$?
    local _response=$(cat "$_response_path" 2>/dev/null)

    if [[ $waldo_extra_args == "--verbose" ]]; then
        echo "$_response"
        echo ""
    fi

    check_build_status "$_response"

    if (( $_curl_status == 0 )); then
        echo "Build ‘${_build_name}’ successfully uploaded to Waldo!"
    fi
}

function upload_symbols() {
    [[ -n $waldo_symbols_path ]] || return 0

    local _symbols_name=$(basename "$waldo_symbols_path")

    local _response_path=$waldo_working_path/symbols_response.json

    echo "Uploading symbols to Waldo"

    [[ $waldo_extra_args == "--verbose" ]] && echo ""

    curl_upload_symbols "$_response_path"

    local _curl_status=$?
    local _response=$(cat "$_response_path" 2>/dev/null)

    if [[ $waldo_extra_args == "--verbose" ]]; then
        echo "$_response"
        echo ""
    fi

    check_symbols_status "$_response"

    if (( $_curl_status == 0 )); then
        echo "Symbols in ‘${_symbols_name}’ successfully uploaded to Waldo!"
    fi
}

function websafe_base64_encode() {
    base64 | tr -d '\n' | tr '/+' '_-' | sed 's/=/%3D/g'
}

display_version

while (( $# )); do
    case $1 in
        --help)
            display_usage
            exit
            ;;

        --include_symbols)
            waldo_include_symbols=true
            ;;

        --upload_token)
            if (( $# < 2 )) || [[ -z $2 || ${2:0:1} == "-" ]]; then
                fail_usage "Missing required value for option: ‘${1}’"
            else
                waldo_upload_token=$2
                shift
            fi
            ;;

        --variant_name)
            if (( $# < 2 )) || [[ -z $2 || ${2:0:1} == "-" ]]; then
                fail_usage "Missing required value for option: ‘${1}’"
            else
                waldo_variant_name=$2
                shift
            fi
            ;;

        --verbose)
            waldo_extra_args="--verbose"
            ;;

        -*)
            fail_usage "Unknown option: ‘${1}’"
            ;;

        *)
            if [[ -z $waldo_build_path ]]; then
                waldo_build_path=$1
            elif [[ -z $waldo_symbols_path ]]; then
                waldo_symbols_path=$1
            else
                fail_usage "Unknown argument: ‘${1}’"
            fi
            ;;
    esac

    shift
done

check_platform || exit
check_build_path || exit
check_symbols_path || exit
check_history || exit
check_upload_token || exit
check_variant_name || exit

create_working_path || exit

create_build_payload || exit
create_symbols_payload || exit

display_summary

upload_build || exit
upload_symbols || exit

delete_working_path # failure is OK

exit
