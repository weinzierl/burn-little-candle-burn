/* QEMU mps2-an505: secure aliases of the two SSRAM blocks.
   RAM is capped at 512 KiB to stay inside the Pico 2 budget
   (RP2350: 520 KiB SRAM). Code and weights: 4 MiB, like the
   Pico 2 flash. */
MEMORY
{
  FLASH : ORIGIN = 0x10000000, LENGTH = 4M
  RAM   : ORIGIN = 0x38000000, LENGTH = 512K
}
