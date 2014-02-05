
# Performs a search in the text for a given pattern. At base,
# uses Levenshtein distance to determine the best match. Augmented
# to keep track of the length of the match. Will return the match
# with the best distance score. If multiple matches are found, the
# longest, ealiest match is selected.
#
# @return [Int, Int] - Returns [location, length] of the found
# match. Returns [-1,0] if no match under the errRate is found.
fuzzyTextSearch = (text, pattern, errRate=0) ->

    return [-1,0] if text.length == 0
    return [0,0] if pattern.length == 0

    tLen = text.length
    pLen = pattern.length
    vals = []
    lengths = []

    for i in [0..tLen]
      vals.push([])
      lengths.push([])
      for j in [0..pLen]
        if i == 0
          vals[i].push(j)
          lengths[i].push(-j)
        else
          vals[i].push(0)
          lengths[i].push(0)

    for i in [1..tLen]
      for j in [1..pLen]
        if text[i-1] == pattern[j-1]
          vals[i][j] = vals[i-1][j-1]
          lengths[i][j] = lengths[i-1][j-1]
        else
          add = vals[i-1][j] + 1
          del = vals[i][j-1] + 1
          sub = vals[i-1][j-1] + 1
          best = Math.min(add, del, sub)
          vals[i][j] = best

          if best == add
            lengths[i][j] = lengths[i-1][j] + 1
          else if best == del
            lengths[i][j] = lengths[i][j-1] - 1
          else if best == sub
            lengths[i][j] = lengths[i-1][j-1]
            
    bestIndex = tLen
    for i in [tLen...0]
      if (vals[i][pLen] < vals[bestIndex][pLen]) or 
         (vals[i][pLen] == vals[bestIndex][pLen] and
          lengths[i][pLen] >= lengths[bestIndex][pLen])
        bestIndex = i

    matchLength = pLen + lengths[bestIndex][pLen]
    if vals[bestIndex][pLen] <= (errRate * pLen)
      return [bestIndex - matchLength, matchLength]
    else
      return [-1, 0]

