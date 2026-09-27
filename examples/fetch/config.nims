# fetch's own switches, read after examples/config.nims (which builds every example): the
# binding's fetcher over std/httpclient, and OpenSSL for its https. The web needs
# neither: the browser downloads.
when not defined(emscripten):
  switch("define", "wgrIncludeFetcher")
  switch("define", "ssl")
