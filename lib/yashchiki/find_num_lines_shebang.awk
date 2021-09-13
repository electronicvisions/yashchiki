BEGIN {
    searching = 1
}

/^#/ {
    if (searching)
        preamble += 1
}

/^([^#]|$)/ {
    searching = 0
}

END {
    print preamble
}
