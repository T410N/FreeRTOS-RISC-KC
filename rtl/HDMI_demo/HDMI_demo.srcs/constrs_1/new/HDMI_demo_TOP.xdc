## ============================================================================
## RV32IM SoC - XDC Constraints for Nexys Video
## Includes: Clock, Reset, Button, LEDs, UART, HDMI TX, PS/2 Keyboard
## ============================================================================

## Clock: 100 MHz
set_property -dict { PACKAGE_PIN R4    IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk];

## Reset (active-low)
set_property -dict { PACKAGE_PIN G4    IOSTANDARD LVCMOS15 } [get_ports { reset_n }];

## Benchmark Start Button (BTNU)
set_property -dict { PACKAGE_PIN F15   IOSTANDARD LVCMOS12 } [get_ports { btn_up }];

## LEDs
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS25 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS25 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS25 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS25 } [get_ports { led[3] }];
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS25 } [get_ports { led[4] }];
set_property -dict { PACKAGE_PIN W16   IOSTANDARD LVCMOS25 } [get_ports { led[5] }];
set_property -dict { PACKAGE_PIN W15   IOSTANDARD LVCMOS25 } [get_ports { led[6] }];
set_property -dict { PACKAGE_PIN Y13   IOSTANDARD LVCMOS25 } [get_ports { led[7] }];

## UART TX
set_property -dict { PACKAGE_PIN AA19  IOSTANDARD LVCMOS33 } [get_ports { uart_tx_in }];

## --------------------------------------------------------------------------
## HDMI TX (Source) - TMDS
## --------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN T1    IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_clk_p }];
set_property -dict { PACKAGE_PIN U1    IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_clk_n }];
set_property -dict { PACKAGE_PIN W1    IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_p[0] }];
set_property -dict { PACKAGE_PIN Y1    IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_n[0] }];
set_property -dict { PACKAGE_PIN AA1   IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_p[1] }];
set_property -dict { PACKAGE_PIN AB1   IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_n[1] }];
set_property -dict { PACKAGE_PIN AB3   IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_p[2] }];
set_property -dict { PACKAGE_PIN AB2   IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_n[2] }];

## --------------------------------------------------------------------------
## PS/2 Keyboard (from PIC24 USB HID bridge)
## --------------------------------------------------------------------------
## PIC24가 USB 키보드를 PS/2로 변환해서 이 핀으로 보내준다.
## PULLUP 필요: PS/2 버스는 오픈-콜렉터이므로 idle 시 HIGH 유지.
set_property -dict { PACKAGE_PIN W17   IOSTANDARD LVCMOS33   PULLUP true } [get_ports { ps2_clk }];
set_property -dict { PACKAGE_PIN N13   IOSTANDARD LVCMOS33   PULLUP true } [get_ports { ps2_data }];

## --------------------------------------------------------------------------
## FPGA Configuration
## --------------------------------------------------------------------------
set_property CONFIG_VOLTAGE 3.3 [current_design];
set_property CFGBVS VCCO [current_design];
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design];
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design];
