(in-package :cl-user)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (ql:quickload "sdl2"))

(defpackage #:NES-console
  (:nicknames #:nes)
  (:use :cl :cl-user :6502-cpu :NES-cartridge :NES-ppu :NES-controller)
  (:export #:make-nes #:console-on #:nes-cpu #:nes-ppu #:nes-cart #:step-nes
           #:step-frame #:setup-and-emulate #:render-nes #:read-rom))

(in-package :NES-console)
(declaim (optimize (speed 3) (safety 1)))
(defstruct nes
  "A model nes"
  (cpu (6502-cpu:make-cpu))
  (cart (NES-cartridge:make-cartridge))
  (ppu (NES-ppu:make-ppu))
  (controllers
   (make-array 2 :initial-contents `(,(nes-controller:make-controller)
                                     ,(nes-controller:make-controller)))
   :type (simple-array NES-controller:controller 1)))

(defvar mirror-lookup
  (make-array
   20
   :element-type '(unsigned-byte 2)
   :initial-contents '(0 0 1 1 0 1 0 1 0 0 0 0 1 1 1 1 0 1 2 3)))

(defun read-rom (n rom-name)
  (declare (nes n))
  (setf (nes-cart n) (NES-cartridge:load-cartridge rom-name)))

(defun get-buttons()
  (let ((buttons (make-array 8 :element-type '(unsigned-byte 8) :initial-element 0)))
    (setf (aref buttons 0) (if (sdl2:keyboard-state-p :scancode-left) 1 0))
    (setf (aref buttons 1) (if (sdl2:keyboard-state-p :scancode-down) 1 0))
    (setf (aref buttons 2) (if (sdl2:keyboard-state-p :scancode-grave) 1 0))
    (setf (aref buttons 3) (if (sdl2:keyboard-state-p :scancode-tab) 1 0))
    (setf (aref buttons 4) (if (sdl2:keyboard-state-p :scancode-w) 1 0))
    (setf (aref buttons 5) (if (sdl2:keyboard-state-p :scancode-s) 1 0))
    (setf (aref buttons 6) (if (sdl2:keyboard-state-p :scancode-a) 1 0))
    (setf (aref buttons 7) (if (sdl2:keyboard-state-p :scancode-d) 1 0))
    buttons))

(defun map-memory (n)
  (setf (NES-ppu:ppu-trigger-nmi-callback (nes-ppu n)) (6502-cpu:trigger-nmi-callback (nes-cpu n)))
  (setf (NES-ppu:ppu-oam-dma-callback (nes-ppu n)) (lambda (addr) (6502-cpu:read-cpu (nes-cpu n) addr)))
  (setf (NES-ppu:ppu-oam-stall-adder (nes-ppu n)) (6502-cpu:add-to-stall (nes-cpu n)))
  (setf
   (aref (the (simple-array function 1) (NES-ppu:ppu-memory-get (nes-ppu n))) 0)
   (ppu-to-mapper-read n))
  (setf
   (aref (the (simple-array function 1) (NES-ppu:ppu-memory-set (nes-ppu n))) 0)
   (ppu-to-mapper-write n))
  (setf
   (aref (the (simple-array function 1) (NES-ppu:ppu-memory-get (nes-ppu n))) 1)
   (ppu-to-name-table-read n))
  (setf
   (aref (the (simple-array function 1) (NES-ppu:ppu-memory-set (nes-ppu n))) 1)
   (ppu-to-name-table-write n))
  (setf
   (aref (the (simple-array function 1) (NES-ppu:ppu-memory-get (nes-ppu n))) 2)
   (ppu-to-palette-read n))
  (setf
   (aref (the (simple-array function 1) (NES-ppu:ppu-memory-set (nes-ppu n))) 2)
   (ppu-to-palette-write n))
  (setf
   (aref (the (simple-array function 1) (6502-cpu:cpu-memory-get (nes-cpu n))) 0)
   (cpu-to-cpu-read n))
  (setf
   (aref (the (simple-array function 1) (6502-cpu:cpu-memory-set (nes-cpu n))) 0)
   (cpu-to-cpu-write n))
  (setf
   (aref (the (simple-array function 1) (6502-cpu:cpu-memory-get (nes-cpu n))) 1)
   (cpu-to-ppu-read n))
  (setf
   (aref (the (simple-array function 1) (6502-cpu:cpu-memory-set (nes-cpu n))) 1)
   (cpu-to-ppu-write n))
  (setf
   (aref (the (simple-array function 1) (6502-cpu:cpu-memory-get (nes-cpu n))) 2)
   (cpu-to-io-read n))
  (setf
   (aref (the (simple-array function 1) (6502-cpu:cpu-memory-set (nes-cpu n))) 2)
   (cpu-to-io-write n))
  (setf
   (aref (the (simple-array function 1) (6502-cpu:cpu-memory-get (nes-cpu n))) 5)
   (cpu-to-cart-read n))
  (setf
   (NES-controller:controller-buttons-callback
    (aref
     (the (simple-array NES-controller:controller 1)(nes-controllers n))
     0))
   #'get-buttons))

(defun console-on (n)
  (declare (nes n))
  (NES-ppu:reset-ppu (nes-ppu n))
  (map-memory n)
  (6502-cpu:power-on (nes-cpu n)))

(defun step-nes (n steps)
  (declare (nes n) ((unsigned-byte 32) steps))
  (loop for s from 1 to steps
    do
    (let ((cycles (* 3 (the (unsigned-byte 8)(6502-CPU:step-cpu (nes-cpu n))))))
      (declare ((unsigned-byte 8) cycles))
      (NES-ppu:step-ppu (nes-ppu n) cycles))))

(defun step-frame (n)
  (declare (nes n))
  (let ((frame (NES-ppu:ppu-frame (nes-ppu n)))
        (controller (aref (the (simple-array nes-controller:controller 1)(nes-controllers n)) 0)))
    (declare ((unsigned-byte 16) frame))
    (loop
      do
      (progn
       (when (not (= frame (NES-ppu:ppu-frame (nes-ppu n)))) (return))
       (nes-controller:update-controller controller)
       (step-nes n 1)))))

(defun test-render-clear (renderer)
  (sdl2:set-render-draw-color renderer 0 0 0 255)
  (sdl2:render-clear renderer))

(defun render-nes (front renderer tex rect)
  (multiple-value-bind
   (pixels pitch)
   (sdl2:lock-texture tex rect)
   (loop for y from 0 to (- NES-ppu:screen-height 1)
    do
    (loop for x from 0 to (- NES-ppu:screen-width 1)
      do
      (let* ((color (aref (the (simple-array NES-ppu:color 1) front) (+ (* y NES-ppu:screen-width) x)))
             (r (color-r color))
             (g (color-g color))
             (b (color-b color))
             (col (logior (ash #xFF 24) (ash r 16) (ash g 8) (ash b 0))))
        (setf (sb-sys:sap-ref-32 pixels (* 4 (+ (* y NES-ppu:screen-width) x))) col))))
   (sdl2:update-texture tex pixels :rect rect :width pitch)
   (sdl2:unlock-texture tex))
  (sdl2:render-copy renderer tex :dest-rect rect))

(defun setup-and-emulate (cart-name)
  (let ((a (make-nes)))
    (read-rom a cart-name)
    (console-on a)
    (sdl2:with-init (:everything)
      (sdl2:with-window (win :title "Potential-Disco" :w NES-ppu:screen-width :h NES-ppu:screen-height :flags '(:shown))
        (sdl2:with-renderer (renderer win :flags '(:accelerated))
          (let* ((tex (sdl2:create-texture
                      renderer
                      :argb8888
                      :streaming
                      NES-ppu:screen-width
                      NES-ppu:screen-height))
                (rect (sdl2:make-rect 0 0 NES-ppu:screen-width NES-ppu:screen-height)))
            (sdl2:with-event-loop (:method :poll)
            (:keyup
             (:keysym keysym)
             (when (sdl2:scancode= (sdl2:scancode-value keysym) :scancode-escape)
               (sdl2:push-event :quit)))
            (:idle
             ()
             ;Update Controller
             (step-frame a)
             (test-render-clear renderer)
             (render-nes (NES-ppu:ppu-front (nes-ppu a)) renderer tex rect)
             (sdl2:render-present renderer))
            (:quit () t))))))))
