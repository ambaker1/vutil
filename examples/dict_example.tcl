package require tin
tin import vutil

# Create dictionary record
new dict record {
    name {John Doe}
    address {
        streetAddress {123 Main Street}
        city {New York}
        state {NY}
        zip {10001}
    }
    phone {555-1234} 
}

# Get values
puts [$record size]; # Number of keys (3)
puts [$record get name]; # John Doe
# Set/unset and get
$record set address street [$record get address streetAddress]
$record unset address streetAddress
puts [$record get address street]; # 123 Main Street
puts [$record exists address streetAddress]; # 0
# Manipulate with normal dict commands
dict lappend $record name Smith
puts [$record get name]
