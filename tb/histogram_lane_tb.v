module histogram_lane_tb;
	reg clock;
	reg reset;
	reg enable;
	reg [7:0] data_in;
	reg [2:0] hist_addr;
	wire [13:0] hist_out;

	histogram_lane histogram_lane(
		.clock(clock),
		.reset(reset),
		.enable(enable),
		.data_in(data_in),
		.hist_addr(hist_addr),
		.hist_out(hist_out)
	);
endmodule