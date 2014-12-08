#!/bin/bash
# NEED TEST ENTER DATA 
login=""
password=""
MAX_COUNT_DOWNLOAD=1000
domain="mail.ru" 
UserAgent="Mozilla/5.0 (compatible; MSIE 7.01; Windows NT 5.0)"

separator="--------------------------------------------------------------------------------"
separator_smal="---------------------------------------------------------------"
bold=`tput bold`
normal=`tput sgr0`

function get_music_list {
    local file_xml=$1
    arr=$(echo "cat /music_list/track/furl" | \
            xmllint --shell $file_xml | sed 's/<[^>]*>//g;s/[-][-]*//g;s/\/[^>]*>//')
    set $arr
    i=0
    while [ $#  -gt 0 ] ; do
      url=$1
      shift
      if [[ $url  =~ ^music.my.mail.ru/file/[0-9A-Fa-f]{32}.mp3 ]]; then
        array[$i]=$url
        let i++
      fi  
    done
}

function download_music_files {
    echo $separator_smal
    echo "Start download files"
    local arra=("${@}")
    local i=0
    for furl in "${arra[@]}"
    do
        if [ "$i" -eq $MAX_COUNT_DOWNLOAD ]; then
            break
        fi
        filename=$(echo $furl | sed 's/music.my.mail.ru\/file\///g')
	if [ ! -f "mp3/$filename" ]; then
            echo "File  $filename not exist in library. Download ..."
            curl -s -L -b onlime.cookies -c onlime.cookies -A "$UserAgent" --create-dirs -o "mp3/$filename" -k $furl
            sleep .$[ ( $RANDOM % 4 ) + 1 ]s
	    let i++
	fi
    done
    echo -e "${bold}Download audio files: \t$i${normal}"
    if [ "$i" -gt 0 ] ; then
	echo "Data placed in the directory mp3/"
    fi
}

function auth_user {
    if ["$login" == ""]; then
        echo -en "Enter email    > "
        read login
    fi
    if ["$password" == ""]; then
        echo -en "Enter password > "
        while IFS= read -p "$prompt" -r -s -n 1 char
        do
            if [[ $char == $'\0' ]]
            then
                break
            fi
            prompt='*'
            password+="$char"
        done
    fi
    echo -e "\n Start Auth:"
    curl -s                      -c onlime.cookies -A "$UserAgent" --ssl -k http://my.mail.ru > /dev/null &&
    curl -s -L -b onlime.cookies -c onlime.cookies -A "$UserAgent" \
           --data "Login=$login&Domain=$domain&Password=$password&saveauth=0&new_auth_form=1&page=&post=&login_from=&lang=ru_RU&setLang=ru_RU" \
	   --ssl -k https://auth.mail.ru/cgi-bin/auth > /dev/null &&
    curl -s -L -b onlime.cookies -c onlime.cookies -A "$UserAgent" -k http://my.mail.ru > /dev/null 
}

function out_to_file {
    local OUT=$1
    local file=$2
    RET_CODE=$(echo "$OUT" | tail -n1)
    echo "Success, HTTP status is: $RET_CODE"

    res=$(echo "$OUT" | sed '$d')
    echo $res > $file
}

function containsElement {
    local e
    for e in "${@:2}"; do 
	if [ "$e" == "$1" ]; then
		 return 0;  fi
    done
    return 1
}

function cut_deleted_file {
    local files=("${@}")
    local i=0
    echo $separator_smal
    echo "Delete old files.."
    for file in mp3/*
    do
        filename=$(echo $file | sed 's/mp3\///g')
	url="music.my.mail.ru/file/$filename"
        containsElement "$url" "${files[@]}"
	notfound_file_inxml=$?
	if [[ "$notfound_file_inxml" -eq 1 ]] ; then
              rm -rf "mp3/$filename"
              echo "File $filename deleted"
              let i++
        fi
    done
    echo -e "${bold}Delete audio files: \t$i${normal}"
}


echo $separator
echo "
____|)_________|___________
|___/___|______|____
|__/|___|-.__,-._______       MY MAIL RU      Music Sync script
|_/(|,\_|/___\`-'______          Ahtung! Use script only for fun.  
|_\_|_/__________                       After fun - delete all downloaded data.
    |                                    ^_^
  (_| "
echo $separator

echo "Get audio list"
OUT=$( curl -qSfsw '\n%{http_code}' -b onlime.cookies -A "$UserAgent" -k http://my.mail.ru/musxml ) 2>/dev/null
RET=$?
if [[ $RET -ne 0 ]] ; then
    RET_CODE=$(echo "$OUT" | tail -n1 )
    echo "HTTP Error: $RET_CODE"
    if [[ $RET_CODE -eq 403 ]] ; then
        echo "Not authorized request. Try auth"
        auth_user       
        OUT=$( curl -qSfsw '\n%{http_code}' -b onlime.cookies  http://my.mail.ru/musxml ) 2>/dev/null
        RET=$?
        if [[ $RET -ne 0 ]] ; then
             echo "Fatal error: can't auth, after send login-password"
             exit
        fi
    else
        echo "Fatal error: on get music list" 
        exit
    fi
fi

out_to_file "$OUT"  "_new_music.xml"
get_music_list "_new_music.xml"
if [ ${#array[@]} -eq 0 ]; then
    echo "Zero music list, or bad format"
    exit
fi
echo -e "${bold}Found audio in list: \t"${#array[@]} "${normal}"
download_music_files "${array[@]}"
cut_deleted_file "${array[@]}"
echo "End script"
echo $separator
rm "_new_music.xml"
