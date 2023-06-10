package require tin
tin import vutil

[new list list1] = {hello world}
puts [$list1 length]; # 2
$list1 @ 0 = "hey"
$list1 @ 1 = "there"
$list1 @ end+1 = "world"
puts [$list1 @ end]; # world
puts [$list1 info]; # exists 1 length 3 type list value {hey there world}

