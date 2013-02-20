require "utils"

u=utils

u.resetTests()

u.check(u.toString({ 1,2,3, test={ 2, "toto" } },2),'{ 1, 2, 3, test = { 2, "toto" } }',"invalid print")

u.check(u.lengthOfTable({}),0,"invalid length")

u.checkSummary()