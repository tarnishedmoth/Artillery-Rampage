class_name EnumUtils

## Gets the string value of an enum
## By default str(MyEnum.VALUE1) would print 0. Use this function to print "VALUE1"
## printing the enum constant as a string literal
static func enum_to_string(enum_type, enum_value) -> String:
    return enum_type.keys()[enum_value]

## Attempts to parse an enum string as an enum constant and returns null if there is no match
static func enum_from_string(enum_type, enum_name:String, case_sensitive:bool = true):
    var index:int = enum_type.keys().find(enum_name) if case_sensitive else enum_type.keys().find_custom(func(v): return v.nocasecmp_to(enum_name))
    return enum_type.values()[index] if index != -1 else null

## Returns the ordinal or index of the enum_value within enum_type
## enum Animal { DOG = 3, CAT = 5, RHINO = 7 } # Animal.RHINO returns 2
static func enum_ordinal(enum_type, enum_value) -> int:
    return enum_type.values().find(enum_value)

## Returns the enum value as an int
## enum Animal { DOG = 3, CAT = 5, RHINO = 7 } # Animal.RHINO returns 7
static func enum_as_int(enum_value) -> int:
    return enum_value as int
