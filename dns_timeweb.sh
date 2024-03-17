#!/usr/bin/env sh

Timeweb_Api="https://api.timeweb.cloud/api/v1"

#Author: Pertsev Dmitriy
#Report Bugs here: https://github.com/pertsevds/acme.sh_dnsapi_timeweb.cloud
#
########  Public functions #####################

#Usage: dns_timeweb_add   _acme-challenge.www.domain.com   "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
dns_timeweb_add() {
  fulldomain=$1
  txtvalue=$2

  _info "Using Timeweb"
  _debug fulldomain "$fulldomain"
  _debug txtvalue "$txtvalue"

  Timeweb_Token="${Timeweb_Token:-$(_readaccountconf_mutable Timeweb_Token)}"

  if [ "$Timeweb_Token" ]; then
    _saveaccountconf_mutable Timeweb_Token "$Timeweb_Token"
  else
    _err "You didn't specify a Timeweb api key yet."
    _err "You can get yours from here https://timeweb.cloud/my/api-keys/create."
    return 1
  fi

  _debug "First detect the root zone"
  if ! _get_root "$fulldomain"; then
    _err "invalid domain"
    return 1
  fi
  _debug _sub_domain "$_sub_domain"
  _debug _domain "$_domain"

  _info "Adding record"
  if _timeweb_rest POST "domains/$_domain/dns-records" "{\"subdomain\":\"$_sub_domain\",\"type\":\"TXT\",\"value\":\"$txtvalue\"}"; then
    if _contains "$response" "$txtvalue"; then
      _info "Added, OK"
      return 0
    elif _contains "$response" "dns_record_exists"; then
      _info "Already exists, OK"
      return 0
    else
      _err "Add txt record error."
      return 1
    fi
  fi
  _err "Add txt record error."
  return 1
}

#Usage: fulldomain txtvalue
#Remove the txt record after validation.
dns_timeweb_rm() {
  fulldomain=$1
  txtvalue=$2

  _info "Using Timeweb"
  _debug fulldomain "$fulldomain"
  _debug txtvalue "$txtvalue"

  Timeweb_Token="${Timeweb_Token:-$(_readaccountconf_mutable Timeweb_Token)}"

  if [ "$Timeweb_Token" ]; then
    _saveaccountconf_mutable Timeweb_Token "$Timeweb_Token"
  else
    _err "You didn't specify a Timeweb api key yet."
    _err "You can get yours from here https://timeweb.cloud/my/api-keys/create."
    return 1
  fi

  _debug "First detect the root zone"
  if ! _get_root "$fulldomain"; then
    _err "invalid domain"
    return 1
  fi
  _debug _sub_domain "$_sub_domain"
  _debug _domain "$_domain"

  _timeweb_rest GET "domains/$_domain/dns-records" ""
  if _contains "$response" "\"dns_records\":"; then
    _records=$(echo "$response" | _egrep_o "\"dns_records\": *\[[^]]*]" | sed -E 's/"dns_records":\[//' | sed -E 's/\]//')
    _record=$(echo "$_records" | _egrep_o "{\"data\":{\"subdomain\":\"_acme-challenge\",\"value\":\"$txtvalue\"},\"id\":([0123456789]+),\"type\":\"TXT\",\"fqdn\":\"$_domain\"}")
    _id=$(echo "$_record" | _egrep_o "\"id\": *[0123456789]+" | cut -d : -f 2)
    _debug2 records "$_records"
    _debug2 record "$_record"
    _debug2 id "$_id"
 
    if _timeweb_rest DELETE "domains/$_domain/dns-records/$_id" ""; then
      _info "Removed, OK"
      return 0
    fi 
  fi
  _err "Remove txt record error."
  return 1

}

####################  Private functions below ##################################
#_acme-challenge.www.domain.com
#returns
# _sub_domain=_acme-challenge.www
# _domain=domain.com
_get_root() {
  domain=$1
  i=1
  p=1

  while true; do
    h=$(printf "%s" "$domain" | cut -d . -f "$i"-100)
    _debug h "$h"
    if [ -z "$h" ]; then
      #not valid
      return 1
    fi

    _timeweb_rest GET "domains/$h"

    if _contains "$response" "\"domain\":"; then
      _domain=$(echo "$response" | sed -E 's/,"subdomains":.+//' | _egrep_o "\"fqdn\": *\"[^\"]*\"" | cut -d : -f 2 | tr -d \" | tr -d " ")
      if [ "$_domain" ]; then
        _sub_domain=$(printf "%s" "$domain" | cut -d . -f 1-"$p")
        return 0
      fi
      return 1
    fi
    p=$i
    i=$(_math "$i" + 1)
  done
  return 1
}

_timeweb_rest() {
  m=$1
  ep="$2"
  data="$3"
  _debug "$ep"

  token_trimmed=$(echo "$Timeweb_Token" | tr -d '"')

  export _H1="Content-Type: application/json"
  export _H2="Authorization: Bearer $token_trimmed"

  if [ "$m" != "GET" ]; then
    _debug data "$data"
    response="$(_post "$data" "$Timeweb_Api/$ep" "" "$m")"
  else
    response="$(_get "$Timeweb_Api/$ep")"
  fi

  if [ "$?" != "0" ]; then
    _err "error $ep"
    return 1
  fi
  _debug2 response "$response"
  return 0
}
