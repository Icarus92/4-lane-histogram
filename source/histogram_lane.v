module histogram_lane (
	input clock,
	input reset,
	input enable,
	input [7:0] data_in,
	input [2:0] hist_addr,
	output reg [13:0] hist_out);

	reg [13:0] bins [7:0];
	integer i;

	always @(posedge clock) begin
		if (reset) begin
			for (i = 0; i < 8; i = i + 1)
				bins[i] <= {14{1'b0}};
		end

		if (enable) begin
			if (data_in >= 0 && data_in < 32)
				bins[0] <= bins[0] + 1;
			else if (data_in >= 32 && data_in < 64)
				bins[1] <= bins[1] + 1;
			else if (data_in >= 64 && data_in < 96)
				bins[2] <= bins[2] + 1;
			else if (data_in >= 96 && data_in < 128)
				bins[3] <= bins[3] + 1;
			else if (data_in >= 128 && data_in < 160)
				bins[4] <= bins[4] + 1;
			else if (data_in >= 160 && data_in < 192)
				bins[5] <= bins[5] + 1;
			else if (data_in >= 192 && data_in < 224)
				bins[6] <= bins[6] + 1;
			else if (data_in >= 224 && data_in < 256)
				bins[7] <= bins[7] + 1;
		end

		hist_out = bins[hist_addr + 1];
	end
endmodule
