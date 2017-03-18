library verilog;
use verilog.vl_types.all;
entity histogram_lane is
    port(
        clock           : in     vl_logic;
        reset           : in     vl_logic;
        enable          : in     vl_logic;
        data_in         : in     vl_logic_vector(7 downto 0);
        hist_addr       : in     vl_logic_vector(2 downto 0);
        hist_out        : out    vl_logic_vector(13 downto 0)
    );
end histogram_lane;
