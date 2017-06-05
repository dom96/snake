import unicode

when not defined(js):
  import httpclient, logging, asyncdispatch, json

  proc getCountryForIP*(ip: string): Future[string] {.async.} =
    ## Returns a two-letter ISO code specifying the country that the
    ## IP address belongs to, if the country cannot be determined "" is returned.
    var client = newAsyncHttpClient()

    let responseFut = client.getContent("http://freegeoip.net/json/" & ip)
    yield responseFut
    if responseFut.failed:
      warn("Error retrieving country by IP: " & responseFut.error.msg)
      return ""

    let obj = parseJson(responseFut.read())
    return obj["country_code"].getStr()

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