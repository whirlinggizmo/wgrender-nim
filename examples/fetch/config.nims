# fetch's own switch, read after examples/config.nims (which builds every example): the
# binding's fetcher, over puppy (which the binding requires). The web needs none: the
# browser downloads.
when not defined(emscripten):
  switch("define", "wgrIncludeFetcher")
