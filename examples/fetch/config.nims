# fetch's own switches, read after examples/config.nims (which builds every example): the
# binding's fetcher over std/httpclient, and OpenSSL for its https. The web needs
# neither: the browser downloads.
when not defined(emscripten):
  switch("define", "wgrIncludeFetcher")
  switch("define", "ssl")
  # Windows: OpenSSL 3's DLLs, not 1.1's (Nim's default), and the program ships them
  # and a cacert.pem beside itself (httpFetcher says why)
  when defined(windows):
    switch("define", "sslVersion=3-x64")
