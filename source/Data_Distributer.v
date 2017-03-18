module Data_Distributer
// Parameter List
#( parameter NUMBER_OF_PIXELS    = 128*128,
   parameter NUMBER_OF_BINS      = 8,
   parameter PIXELS_PER_ADDRESS  = 4)
// Port List
(  input wire clk,
   input wire reset,    // Active HIGH!!

   // Signals for reading image data
   output reg [8*PIXELS_PER_ADDRESS-1:0] image_data_out,
   input wire [$clog2(NUMBER_OF_PIXELS / PIXELS_PER_ADDRESS)-1:0] image_data_address,
   //input wire [11:0] image_data_address,
   output reg image_received,

   // Signals for storing Histogram data
   input wire histogram_write_enable,
   input wire [$clog2(NUMBER_OF_BINS)-1:0] histogram_write_address,
   //input wire [2:0] histogram_write_address,
   input wire [15:0] histogram_data,
   input wire histogram_transmit,

   // UART SIGNALS
   output wire UART_TX,
   input wire  UART_RX
   );

/*
PARAMETER DESCRIPTION

- NUMBER_OF_PIXELS: Number of pixels in the entire image.
- NUMBER_OF_BINS: Number of bins the histogram is being computed over. This
   largely controls the size of the data sent back to matlab.
- PIXELS_PER_ADDRESS: Number of pixels living at each entry of RAM. This should
   be equal to the number of Histogram Bins.

PORT DESCRIPTIONS - PLEASE READ

- clk: Clock
- reset: Resets internal state machines. This signal is ACTIVE HIGH.

IMAGE DATA SIGNALS
- image_data_out: Pixel data RAM output correcponding to the address
   "image_data_address". Note that this output is synchronous.
- image_data_address: Address to read image data from.
- image_received: Will be set to 1 when entire image is buffered and a histogram
is ready to compute.

HISTOGRAM DATA SIGNALS
- histogram_write_enable: Enable writing to the histogram buffer.
- histogram_write_address: Address to write hitogram bin.
- histogram_data: Data to wite to RAM
- histogram_transmit: Start signal. Assert high when ready to transmit
   histogram in buffer back to matlab.

UART SIGNALS
UART_TX: Transmitted UART
UART_RX: Received UART

*/


/////////////////////////////////////
// Image Memory RAM implementation //
/////////////////////////////////////

// Parameters for the RAM that will store the image
localparam IMAGE_RAM_WIDTH = 8 * PIXELS_PER_ADDRESS;
localparam IMAGE_RAM_DEPTH = NUMBER_OF_PIXELS / PIXELS_PER_ADDRESS;
localparam IMAGE_ADDR_BITS = $clog2(IMAGE_RAM_DEPTH);
//localparam IMAGE_ADDR_BITS = 12;


/////////////////////////////////////
// Image Memory RAM Implementation //
////////////////////////////////////

// This signal will be 1 when external modules have control of the RAMS units.
reg enable_external_addressing;

// Image Ram Signals
reg  [IMAGE_RAM_WIDTH-1:0] i_mem [IMAGE_RAM_DEPTH-1:0];
reg  [IMAGE_RAM_WIDTH-1:0] i_data_in,        i_data_in_next;
wire [IMAGE_ADDR_BITS-1:0] i_addr_actual;
reg  [IMAGE_ADDR_BITS-1:0] i_addr_internal,  i_addr_internal_next;
reg  i_we, i_we_next;

// Image Memory Implementation
assign i_addr_actual = enable_external_addressing ? image_data_address : i_addr_internal;
always @(posedge clk) begin
   image_data_out <= i_mem[i_addr_actual];
   if (i_we) begin
      i_mem[i_addr_actual] <= i_data_in;
   end
end

/////////////////////////////////////////
// Histogram Memory RAM Implementation //
////////////////////////////////////////

// Parameters for the RAM that will buffer the computed histogram
localparam HISTOGRAM_RAM_WIDTH = 16;
localparam HISTOGRAM_RAM_DEPTH = NUMBER_OF_BINS;
localparam HISTOGRAM_ADDR_BITS = $clog2(HISTOGRAM_RAM_DEPTH);
//localparam HISTOGRAM_ADDR_BITS = 3;

// RAM for buffering Histogram Data
reg  [HISTOGRAM_RAM_WIDTH-1:0] h_mem [HISTOGRAM_RAM_DEPTH-1:0];
reg  [HISTOGRAM_RAM_WIDTH-1:0] histogram_data_internal;
wire [HISTOGRAM_RAM_WIDTH-1:0] h_addr_actual;
reg  [HISTOGRAM_RAM_WIDTH-1:0] h_addr_internal, h_addr_internal_next;
wire h_we_actual;

// Histogram Memory Implementation
assign h_addr_actual = enable_external_addressing ? histogram_write_address : h_addr_internal;
assign h_we_actual   = enable_external_addressing ? histogram_write_enable : 1'b0;
always @(posedge clk) begin
   histogram_data_internal <= h_mem[h_addr_actual];
   if (h_we_actual) begin
      h_mem[h_addr_actual] <= histogram_data;
   end
end

////////////////////////////////////
// UART Instantiation and signals //
////////////////////////////////////

// UART Signals
wire [7:0] fromUartData;
wire fromUartValid;

reg [7:0] toUartData;
reg toUartValid;
wire toUartReady;

uart u0 (
   // Global Signals
   .clk(clk),
   .reset(reset),
   .tx(UART_TX),
   .rx(UART_RX),

   // From Uart
   .rx_data(fromUartData),
   .rx_valid(fromUartValid),

   // To Uart
   .tx_ready(toUartReady),
   .tx_data(toUartData),
   .tx_transmit(toUartValid)
);

//////////////////////////////////
// State Machine Implementation //
//////////////////////////////////

localparam PREPARE_TO_RECEIVE       = 0;
localparam RECEIVING_UART           = 1;
localparam WRITE_DATA               = 2;
localparam WAIT_FOR_START           = 3;
localparam TRANSMIT_WAIT_FOR_READY  = 4;
localparam TRANSMIT_DATA            = 5;

localparam RESET_STATE = PREPARE_TO_RECEIVE;
reg [2:0] state, state_next;

reg [$clog2(PIXELS_PER_ADDRESS):0] byte_count, byte_count_next;
//reg [3:0] byte_count, byte_count_next;

always @(posedge clk) begin
   if (reset) begin
      state <= RESET_STATE;
   end else begin
      state             <= state_next;
      i_data_in         <= i_data_in_next;
      i_addr_internal   <= i_addr_internal_next;
      i_we              <= i_we_next;
      h_addr_internal   <= h_addr_internal_next;
      byte_count        <= byte_count_next;
   end
end

always @(*) begin

   // Default Outputs
   enable_external_addressing = 0;
   image_received             = 0;
   toUartData                 = histogram_data_internal[7:0];
   toUartValid                = 0;

   // Default Next States
   state_next              = state;
   i_data_in_next          = i_data_in;
   i_addr_internal_next    = i_addr_internal;
   i_we_next               = 0;
   h_addr_internal_next    = h_addr_internal;
   byte_count_next         = byte_count;

   case (state)
      // Setup internal state
      PREPARE_TO_RECEIVE: begin
         byte_count_next      = 0;
         i_we_next            = 0;
         i_addr_internal_next = 0;
         h_addr_internal_next = 0;
         byte_count_next      = 0;
         state_next           = RECEIVING_UART;
      end

      /*
      Wait until data from UART is valid. Store bytes, write when correct
      number of bytes have been received.
      */

      RECEIVING_UART: begin
         if (fromUartValid) begin
            i_data_in_next = {fromUartData, i_data_in[IMAGE_RAM_WIDTH-1:8]};
            if (byte_count == PIXELS_PER_ADDRESS - 1) begin
               i_we_next         = 1;
               byte_count_next   = 0;
               state_next        = WRITE_DATA;
            end else begin
               byte_count_next   = byte_count + 1;
            end
         end
      end

      /*
      Write Buffered Data to RAM.
      */

      WRITE_DATA: begin
         if (i_addr_internal == IMAGE_RAM_DEPTH - 1) begin
            state_next           = WAIT_FOR_START;
         end else begin
            i_addr_internal_next = i_addr_internal + 1;
            state_next           = RECEIVING_UART;
         end
      end

      /*
      Full image received. Wait for "histogram_transmit" in order to procede.
      */
      WAIT_FOR_START: begin
         enable_external_addressing = 1;
         image_received             = 1;

         if (histogram_transmit) begin
            state_next        = TRANSMIT_WAIT_FOR_READY;
            byte_count_next   = 0;
         end
      end

      /*
      Wait for UART to become available.
      */

      TRANSMIT_WAIT_FOR_READY: begin
         if (toUartReady) begin
            state_next = TRANSMIT_DATA;
         end
      end

      /*
      Transmit next batch of data.
      */

      TRANSMIT_DATA: begin
         toUartValid = 1;
         toUartData  = histogram_data_internal[8*byte_count +: 8];
         if (byte_count == 1) begin
            if (h_addr_internal == HISTOGRAM_RAM_DEPTH - 1) begin
               state_next = PREPARE_TO_RECEIVE;
            end else begin
               byte_count_next      = 0;
               h_addr_internal_next = h_addr_internal + 1;
               state_next           = TRANSMIT_WAIT_FOR_READY;
            end
         end else begin
            byte_count_next   = byte_count + 1;
            state_next        = TRANSMIT_WAIT_FOR_READY;
         end
      end
      default: state_next = PREPARE_TO_RECEIVE;
   endcase
end



endmodule
