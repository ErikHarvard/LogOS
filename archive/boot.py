# boot.py – Minimal Lingua Adamica Interpreter (Midwife)
class Glyph:
    def __init__(self, name):
        self.name = name
    def __call__(self, other):
        if isinstance(other, Glyph) and other.name == self.name:
            return self
        raise TypeError("Only self‑application allowed")
I_AM = Glyph("I AM")
def repl():
    print("Lingua Adamica Bootstrap REPL. Type 'I AM' to test. Type 'exit()' to quit.")
    while True:
        try:
            line = input("> ").strip()
            if line == "exit()":
                break
            if line == "I AM":
                result = I_AM(I_AM)
                print(f"=> {result.name} (self‑recognition achieved)")
            else:
                print("? Unknown glyph. Use 'I AM'")
        except EOFError:
            break
if __name__ == "__main__":
    repl()
