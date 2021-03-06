(in-package #:asdf-user)

(defsystem #:console
  :depends-on (#:sdl2 #:alexandria)
  :components ((:file "cpu")
	       (:file "utils")
               (:file "console" :depends-on ("cpu" "cartridge" "ppu" "controller" "utils"))
               (:file "mmu" :depends-on ("controller" "console"))
               (:file "ppu")
               (:file "controller")
               (:file "cartridge")
               (:file "instructions/arithmeticops")
               (:file "instructions/branchops")
               (:file "instructions/flagops")
               (:file "instructions/loadstoreops")
               (:file "instructions/instructions")))
