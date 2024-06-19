# operating conditions and boundary conditions #

set clk_period 12.16


#Don't touch the basic environment setting as below

set input_max   [expr { double($clk_period * 0.5) }]
set input_min   [expr { double($clk_period * 0.1) }]
set output_max  [expr { double($clk_period * 0.5) }]
set output_min  [expr { double($clk_period * 0.1) }]

#=====================================================================
# Setting Clock Constraints
#=====================================================================
create_clock -name CLK  -period $clk_period   [get_ports CLK]

set_clock_uncertainty -rise_from [get_clocks CLK] -rise_to [get_clocks CLK] 0.02
set_clock_uncertainty -rise_from [get_clocks CLK] -fall_to [get_clocks CLK] 0.02
set_clock_uncertainty -fall_from [get_clocks CLK] -rise_to [get_clocks CLK] 0.02
set_clock_uncertainty -fall_from [get_clocks CLK] -fall_to [get_clocks CLK] 0.02

#==========================================================
# Setting Design Environment
#==========================================================
set_input_delay  -clock CLK  -max $input_max  [remove_from_collection [all_inputs] [get_ports CLK]]
set_input_delay  -clock CLK  -min $input_min  [remove_from_collection [all_inputs] [get_ports CLK]]

set_output_delay -clock CLK  -max $output_max [all_outputs]
set_output_delay -clock CLK  -min $output_min [all_outputs]
