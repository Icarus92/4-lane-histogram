module histogram_top
/* Parameter list */
#(	parameter BIN_COUNT = 8,
	parameter RAM_BIT_WIDTH = 32,
	parameter BITS_PER_PIXEL = 8,
	parameter IMAGE_PIXEL_COUNT = 128 * 128)
/* Port list */
(	input CLOCK_50,
	/* Reset */
	input [0:0] KEY,

	/* UART */
	input UART_RXD,
	output UART_TXD,

	output wire [0:0] LEDG
);

wire [RAM_BIT_WIDTH - 1:0] image_data_out;
reg [$clog2(IMAGE_PIXEL_COUNT / RAM_BIT_WIDTH * BITS_PER_PIXEL) - 1:0] image_data_address;
wire image_received;
reg histogram_write_enable;
reg [$clog2(BIN_COUNT) - 1:0] histogram_write_address;
reg [$clog2(BIN_COUNT) - 1:0] next_histogram_write_address;
wire [15:0] histogram_data;
reg histogram_transmit = 0;
reg reset_lanes;
reg s = 0;

/* State variables */
reg [2:0] current_state;
reg [2:0] next_state;

/* Enable histogram lanes */
reg histogram_lane_enable;
/* Output from histogram lanes */
wire [13:0] hist_out [3:0];

Data_Distributer data_distributer (
	.clk(CLOCK_50),
	.reset(~KEY[0]),
	.image_data_out(image_data_out),
	.image_data_address(image_data_address),
	.image_received(image_received),
	.histogram_write_enable(histogram_write_enable),
	.histogram_write_address(histogram_write_address),
	.histogram_data(histogram_data),
	.histogram_transmit(histogram_transmit),
	.UART_TX(UART_TXD),
	.UART_RX(UART_RXD)
);
histogram_lane histogram_lane_0 (
	.clock(CLOCK_50),
	.reset(reset_lanes),
	.enable(histogram_lane_enable),
	.data_in(image_data_out[7:0]),
	.hist_addr(histogram_write_address),
	.hist_out(hist_out[0])
);
histogram_lane histogram_lane_1 (
	.clock(CLOCK_50),
	.reset(reset_lanes),
	.enable(histogram_lane_enable),
	.data_in(image_data_out[15:8]),
	.hist_addr(histogram_write_address),
	.hist_out(hist_out[1])
);
histogram_lane histogram_lane_2 (
	.clock(CLOCK_50),
	.reset(reset_lanes),
	.enable(histogram_lane_enable),
	.data_in(image_data_out[23:16]),
	.hist_addr(histogram_write_address),
	.hist_out(hist_out[2])
);
histogram_lane histogram_lane_3 (
	.clock(CLOCK_50),
	.reset(reset_lanes),
	.enable(histogram_lane_enable),
	.data_in(image_data_out[31:24]),
	.hist_addr(histogram_write_address),
	.hist_out(hist_out[3])
);

assign LEDG[0] = s;

initial begin
	histogram_transmit = 0;
	current_state = 3'b000;
	next_state = 3'b000;
	image_data_address = {$clog2(IMAGE_PIXEL_COUNT / RAM_BIT_WIDTH * BITS_PER_PIXEL){1'b0}};
	//histogram_write_address = {3{1'b0}};
end
//$clog2(BIN_COUNT)
always @(posedge CLOCK_50 or negedge KEY[0]) begin
	if (~KEY[0])
		current_state = 3'b000;
	else
		current_state = next_state;
end

assign histogram_data = hist_out[0] + hist_out[1] + hist_out[2] + hist_out[3];

always @(*) begin
	histogram_write_address = next_histogram_write_address;
end

always @(posedge CLOCK_50) begin
	case (current_state)
	3'b000: begin
		reset_lanes = 0;
		histogram_lane_enable = 1'b0;
		histogram_write_enable = 1'b0;

		if (image_received) begin
			/* Start reading image from adress 0 */
			image_data_address = {$clog2(IMAGE_PIXEL_COUNT / RAM_BIT_WIDTH * BITS_PER_PIXEL){1'b0}};
			next_histogram_write_address = {{($clog2(BIN_COUNT) - 1){1'b0}},{1'b1}};
			next_state = 3'b001;
		end else
			next_state = 3'b000;
	end
	3'b001: begin
		/* Enable histogram computation for lanes */
		histogram_lane_enable = 1'b1;

		if (image_data_address == {$clog2(IMAGE_PIXEL_COUNT / RAM_BIT_WIDTH * BITS_PER_PIXEL){1'b1}}) begin
			/* Start writing histogram bin 0 */
			histogram_lane_enable = 1'b0;
			histogram_write_enable = 1'b0;
			next_histogram_write_address = {{($clog2(BIN_COUNT) - 1){1'b0}},{1'b1}};
			next_state = 3'b101;
		end else begin
			/* Move to next RAM address */
			image_data_address = image_data_address + 1;
			next_state = 3'b001;
		end
	end
	3'b101: begin
		next_state = 3'b100;
	end
	3'b100: begin
		/* Enable writing histogram data to distributer */
		histogram_write_enable = 1'b1;
		next_histogram_write_address = histogram_write_address + 1;

		if (histogram_write_address == 0) begin
			histogram_write_enable = 1'b1;
			s = 1;
			next_state = 3'b011;
		end else begin
			next_state = 3'b010;
		end
	end
	3'b010: begin
		histogram_write_enable = 1'b0;
		//histogram_write_address = histogram_write_address + 1;
		next_state = 3'b100;
	end
	3'b011: begin
		histogram_transmit = 1;
		reset_lanes = 1;
		next_state = 3'b000;
	end
	endcase
end
endmodule
