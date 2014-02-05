
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
          lengths[i][pLen] > lengths[bestIndex][pLen])
        bestIndex = i

    matchLength = pLen + lengths[bestIndex][pLen]
    if vals[bestIndex][pLen] <= (errRate * pLen)
      return [bestIndex - matchLength, matchLength]
    else
      return [-1, 0]


fuzzyCases = [
  {
    args: ["abc", "aabc", 1],
    res: [0, 3]
  },
  {
    args: ["abbc", "abac", 1],
    res: [0, 4]
  },
  {
    args: ["abbc", "abc", 1],
    res: [0, 4]
  },
  {
    args: ["abc", "aabc", .3],
    res: [0, 3] 
  }, 
  {
    args: ["abcd", "bbcd", .2],
    res: [-1, 0]
  },
  {
    args: ["abcdefgh", "abbcdxfh", 1],
    res: [0, 8]
  },
  {
    args: ["abcdefg", "effg", 1], 
    res: [4, 3]
  },
  {
    args: ["aaaabcddddd", "dabc", 1],
    res: [3, 3]
  }
]

# (console.log(fuzzyTextSearch.apply(this, c.args), c.res)) for c in fuzzyCases
