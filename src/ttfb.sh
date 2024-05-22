#!/usr/bin/env bash

# -------------------------------------------------------------------------------- #
# Description                                                                      #
# -------------------------------------------------------------------------------- #
# This is a simple script to calculate the 'Time to First Byte' for any given url. #
#                                                                                  #
# The default set of timing information can be changed to show less or more        #
# depending on which parameters are passed on the command line.                    #
#                                                                                  #
# It has 4 main parameters:                                                        #
#                                                                                  #
# -f = Show full set of timing values (default false)                              #
# -m = Show minimal setof timing values (default false)                            #
# -c = How many times to test (default 1)                                          #
# -u = The url to test                                                             #
# -------------------------------------------------------------------------------- #

# -------------------------------------------------------------------------------- #
# Global Variables                                                                 #
# -------------------------------------------------------------------------------- #
# The following global variables are used simple to make the header look nice.     #
# -------------------------------------------------------------------------------- #

SCRIPT_TITLE="Time to First Byte Tester"

# -------------------------------------------------------------------------------- #
# Required commands                                                                #
# -------------------------------------------------------------------------------- #
# These commands MUST exist in order for tyhe script to correctly run.             #
# -------------------------------------------------------------------------------- #

COMMANDS=( "curl" )

# -------------------------------------------------------------------------------- #
# Flags                                                                            #
# -------------------------------------------------------------------------------- #
# Flags which control the output of the timing information.                        #
#                                                                                  #
# -f = Show full set of timing values (default false)                              #
# -m = Show minimal set of timing values (default false)                           #
# -------------------------------------------------------------------------------- #

FULL_TIMINGS=false
MINIMAL_TIMINGS=false

# -------------------------------------------------------------------------------- #
# Utiltity Functions                                                               #
# -------------------------------------------------------------------------------- #
# The following functions are all utility functions used within the script but     #
# are not specific to the display of the colours and only serve to handle things   #
# like, signal handling, user interface and command line option processing.        #
# -------------------------------------------------------------------------------- #

# -------------------------------------------------------------------------------- #
# Signal Handling                                                                  #
# -------------------------------------------------------------------------------- #
# This function is execute when a SIGINT or SIGTERM is caught. It allows us to     #
# exit the script nice and clean so do we not mess up the end users terminal.      #
# -------------------------------------------------------------------------------- #

function control_c()
{
    printf '%s\n** Trapped CTRL-C **\n\n' "${reset}"
    show_footer
    exit
}

# -------------------------------------------------------------------------------- #
# Init                                                                             #
# -------------------------------------------------------------------------------- #
# A simple init function which will setup anything that is needed at the start of  #
# the script, for example set up the signal handler and work out the width of the  #
# screen that we have available.                                                   #
# -------------------------------------------------------------------------------- #

function init()
{
    trap control_c SIGINT
    trap control_c SIGTERM
}

# -------------------------------------------------------------------------------- #
# Check Colours                                                                    #
# -------------------------------------------------------------------------------- #
# This function will check to see if we are able to support colours and how many   #
# we are able to support.                                                          #
#                                                                                  #
# The script will give and error and exit if there is no colour support or there   #
# are less than 8 supported colours.                                               #
#                                                                                  #
# Variables intentionally not defined 'local' as we want them to be global.        #
#                                                                                  #
# NOTE: Do NOT use show_error for the error messages are it requires colour!       #
# -------------------------------------------------------------------------------- #

function check_colours()
{
    local ncolors

    red=''
    cls=''
    reset=''

    if ! test -t 1; then
        return
    fi

    if ! tput longname > /dev/null 2>&1; then
        return
    fi

    ncolors=$(tput colors)

    if ! test -n "${ncolors}" || test "${ncolors}" -le 7; then
        return
    fi

    red=$(tput setaf 1)
    cls=$(tput clear)
    reset=$(tput sgr0)
}

# -------------------------------------------------------------------------------- #
# Center text                                                                      #
# -------------------------------------------------------------------------------- #
# This is a simple function that will center text on a screen, be calculating the  #
# correct amount of padding based on the 'screen_width' and the length of the text #
# supplied to the function.                                                        #
# -------------------------------------------------------------------------------- #

function center_text()
{
    local textsize=${#1}
    local span=$(((screen_width + textsize) / 2))

    printf '%*s\n' "${span}" "$1"
}

# -------------------------------------------------------------------------------- #
# Draw Line                                                                        #
# -------------------------------------------------------------------------------- #
# This function will draw a line on the screen to a given width. It does this by   #
# using 'screen_width' and by adding control codes to create an unbroken line.     #
# -------------------------------------------------------------------------------- #

function draw_line()
{
    local start=$'\e(0' end=$'\e(B' line='qqqqqqqqqqqqqqqq'

    while ((${#line} < screen_width));
    do
        line+="$line";
    done
    printf '%s%s%s\n' "$start" "${line:0:screen_width}" "$end"
}

# -------------------------------------------------------------------------------- #
# Show Header                                                                      #
# -------------------------------------------------------------------------------- #
# This is a simple wrapper function to make display the header easier to do. It    #
# will handle multiple lines passed as seperate parameters.                        #
#                                                                                  #
# In addition it will clear the screen fire, and wrap the header between to        #
# unbroken lines - attempting to make a cleaner interface for the end user.        #
# -------------------------------------------------------------------------------- #

function show_header()
{
    printf '%s' "${cls}"

    draw_line

    if [[ $# -gt 0 ]]; then
        for i in "$@"
        do
            center_text "${i}"
        done
        draw_line
    fi
}

# -------------------------------------------------------------------------------- #
# Show Footer                                                                      #
# -------------------------------------------------------------------------------- #
# A very simple (almost pointless) wrapper which will draw a line after at the     #
# bottom of the screen. We could just called 'draw_line' instead but this was      #
# added for 2 reasons. 1. Constistancy - we have draw_header, 2. Extensibility -   #
# we might want to do more things in the footer at a later date.                   #
# -------------------------------------------------------------------------------- #

function show_footer()
{
    draw_line
}

# -------------------------------------------------------------------------------- #
# Show Error                                                                       #
# -------------------------------------------------------------------------------- #
# A simple wrapper function to show something was an error.                        #
# -------------------------------------------------------------------------------- #

function show_error()
{
    if [[ -n $1 ]]; then
        printf '%s%s%s\n' "${red}" "${*}" "${reset}" 1>&2
    fi
}

# -------------------------------------------------------------------------------- #
# Validate URL                                                                     #
# -------------------------------------------------------------------------------- #
# Ensure that the url we have been given actually exists and is accessible.        #
# -------------------------------------------------------------------------------- #

function validate_url()
{
    if ! curl -o /dev/null --silent --head --fail --connect-timeout 1 "${URL}"; then
        show_error "${URL} does not exist - aborting"
        exit
    fi
}

# -------------------------------------------------------------------------------- #
# Display Timing                                                                   #
# -------------------------------------------------------------------------------- #
# Calculate and display the timing information for the given url.                  #
#                                                                                  #
# Tweak the output depending on the CLI parameters used (-m/-f).                   #
# -------------------------------------------------------------------------------- #

function  display_timing()
{
    show_header "${SCRIPT_TITLE}" "Results for: ${URL}"

    for ((i=1; i<=COUNT; i++))
    do
        if [[ "${MINIMAL_TIMINGS}" = true ]]; then
            curl -L -o /dev/null -H 'Cache-Control: no-cache' -s -w '  StartXfer Time (TTFB): %{time_starttransfer}   Total Time: %{time_total}\n' "${URL}"
        elif [[ "${FULL_TIMINGS}" = true ]]; then
            curl -L -o /dev/null -H 'Cache-Control: no-cache' -s -w '  Lookup Time: %{time_namelookup}   Connect Time: %{time_connect}   AppCon Time: %{time_appconnect}   PreXfer Time: %{time_pretransfer}   Redirect Time: %{time_redirect}   StartXfer Time (TTFB): %{time_starttransfer}   Total Time: %{time_total}\n' "${URL}"
        else
            curl -L -o /dev/null -H 'Cache-Control: no-cache' -s -w '  Lookup Time: %{time_namelookup}   Connect Time: %{time_connect}   StartXfer Time (TTFB): %{time_starttransfer}   Total Time: %{time_total}\n' "${URL}"
        fi
    done

    show_footer
}

# -------------------------------------------------------------------------------- #
# Check Prerequisites                                                              #
# -------------------------------------------------------------------------------- #
# Check to ensure that the prerequisite commmands exist.                           #
# -------------------------------------------------------------------------------- #

function check_prereqs()
{
    local error_count=0

    for i in "${COMMANDS[@]}"
    do
        command=$(command -v "${i}")
        if [[ -z $command ]]; then
            show_error "$i is not in your command path"
            error_count=$((error_count+1))
        fi
    done

    if [[ $error_count -gt 0 ]]; then
        show_error "$error_count errors located - fix before re-running";
        exit 1;
    fi
}

# -------------------------------------------------------------------------------- #
# Usage (-h parameter)                                                             #
# -------------------------------------------------------------------------------- #
# This function is used to show the user 'how' to use the script.                  #
# -------------------------------------------------------------------------------- #

function usage()
{
cat <<EOF

  Usage: $0 [ -hfm ] [ -c count ] [ -u url ]

    -h    : Print this screen
    -f    : Show full set of timing values
    -m    : Show minimal setof timing values
    -c    : How many times to test
    -u    : The url to test

EOF
    exit 1;
}

# -------------------------------------------------------------------------------- #
# Process Input                                                                    #
# -------------------------------------------------------------------------------- #
# This function will process the input from the command line and work out what it  #
# is that the user wants to see.                                                   #
#                                                                                  #
# This is the main processing function where all the processing logic is handled.  #
# -------------------------------------------------------------------------------- #

function process_input()
{
    if [[ $# -eq 0 ]]; then
        usage
    fi

    while getopts ":hfmc:u:" arg
    do
        case $arg in
            h)
                usage
                ;;
            f)
                FULL_TIMINGS=true
                ;;
            m)
                MINIMAL_TIMINGS=true
                ;;
            c)
                COUNT=$OPTARG
                ;;
            u)
                URL=$OPTARG
                ;;
            :)
                show_error "Option -$OPTARG requires an argument."
                usage
                ;;
            \?)
                show_error "Invalid option: -$OPTARG"
                ;;
        esac
    done

    [[ -z "${URL}" ]] && URL=${!#}

    if [[ "${FULL_TIMINGS}" = true ]] && [[ "${MINIMAL_TIMINGS}" = true ]]; then
        show_error "Full and minimal are mutually exclusive - please select only one (or neither)"
        exit
    fi

    [[ -z "${URL}" ]] && usage
    [[ -z "${COUNT}" ]] && COUNT=1

    if [[ "${COUNT}" -lt 1 ]] || [[ "${COUNT}" -gt 25 ]]; then
        show_error "Count must be between 1-25!"
        exit
    fi

    if [[ "${FULL_TIMINGS}" = true ]]; then
        screen_width=182
    elif [[ "${MINIMAL_TIMINGS}" = true ]]; then
        screen_width=58
    else
        screen_width=107
    fi

    validate_url "${URL}"

    display_timing
}

# -------------------------------------------------------------------------------- #
# Main()                                                                           #
# -------------------------------------------------------------------------------- #
# This is the actual 'script' and the functions/sub routines are called in order.  #
# -------------------------------------------------------------------------------- #

init
check_colours
check_prereqs
process_input "$@"

# -------------------------------------------------------------------------------- #
# End of Script                                                                    #
# -------------------------------------------------------------------------------- #
# This is the end - nothing more to see here.                                      #
# -------------------------------------------------------------------------------- #
