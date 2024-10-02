import gdb
pp = gdb.printing.RegexpCollectionPrettyPrinter("lpp")

class lake(gdb.Command):
    def __init__(self):
        super(lake, self).__init__("lake", gdb.COMMAND_USER)

    def invoke(self, arg, tty):
        try:
            gdb.execute(f"shell ./bin/lake {arg}", from_tty=True)
        except Exception as e:
            print(f"{self.__class__.__name__} error: {e}")
lake()

class str_printer:
    def __init__(self, val):
        self.val = val

    def to_string(self):
        s = int(self.val["ptr"])
        len = self.val["len"]
        if len == 0:
            return "{empty}"
        if len > 99999999:
            return "{uninitialized}"
        buf = gdb.selected_inferior().read_memory(s, len).tobytes().decode()
        buf = buf.replace('\n', '\\n')
        buf = buf.replace('\t', '\\t')
        return f"\"{buf}\""
pp.add_printer("str", r"^iro::utf8::str$", str_printer)

class Path_printer:
    def __init__(self, val):
        self.val = val

    def to_string(self):
        val = self.val
        evalstr = f"(({val['buffer'].type}*)({val['buffer'].address}))->asStr()"
        s = gdb.parse_and_eval(evalstr)
        return s
pp.add_printer("Path", r"^iro::fs::Path$", Path_printer)

# class vec2f_printer:
#     def __init__(self, val):
#         self.val = val
# 
#     def to_string(self):
#         val = self.val
#         return f"({val['x']}, {val['y']})"
# pp.add_printer("vec2f", r"^vec2<float>$", vec2f_printer)
# 
# class vec4f_printer:
#     def __init__(self, val):
#         self.val = val
# 
#     def to_string(self):
#         val = self.val
#         return f"({val['x']}, {val['y']}, {val['z']}, {val['w']})"
# pp.add_printer("vec4f", r"^vec4<float>$", vec4f_printer)

class vec2_printer:
    def __init__(self, val):
        self.val = val

    def to_string(self):
        val = self.val
        return f"({val['x']}, {val['y']})"
pp.add_printer("vec2", r"^vec2<.*?>$", vec2_printer)

class vec4_printer:
    def __init__(self, val):
        self.val = val

    def to_string(self):
        val = self.val
        return f"({val['x']}, {val['y']}, {val['z']}, {val['w']})"
pp.add_printer("vec4", r"^vec4<.*?>$", vec4_printer)

gdb.printing.register_pretty_printer(gdb.current_objfile(), pp)
