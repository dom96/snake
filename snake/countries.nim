import unicode

when not defined(js):
  import httpclient, logging, asyncdispatch, json, tables, os

  var countryCache: Table[string, string] = initTable[string, string]()

  proc getCountryForIP*(ip: string): Future[string] {.async.} =
    ## Returns a two-letter ISO code specifying the country that the
    ## IP address belongs to, if the country cannot be determined "" is returned.
    if ip in countryCache:
      return countryCache[ip]

    var client = newAsyncHttpClient()
    defer: client.close()

    let accessKey = getEnv("IPSTACK_KEY")
    if accessKey == "":
      warn("IPSTACK_KEY not set. Cannot retrieve country flags.")
      return

    let responseFut = client.getContent("http://api.ipstack.com/" & ip & "?format=1&access_key=" & accessKey)
    yield responseFut
    if responseFut.failed:
      warn("Error retrieving country by IP: " & responseFut.error.msg)
      return ""

    let obj = parseJson(responseFut.read())
    if "error" in obj:
      warn("Error retrieving country by IP: " & $obj)
      return ""

    countryCache[ip] = obj["country_code"].getStr()
    return countryCache[ip]

proc getUnicodeForCountry*(iso: string): string =
  ## Retrieves a country flag unicode character for the specified ISO two-letter
  ## country code.
  let base = 127397
  result = ""
  for c in iso:
    result.add($Rune(base + c.ord))

  if result.len == 0:
    return "      "

when isMainModule:
  doAssert getUnicodeForCountry("DE") == "🇩🇪"