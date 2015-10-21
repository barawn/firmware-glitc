// Bitstream:
// Bit 0: Start Bit (always 1). Followed by 70 clocks of data.
// Bit 1: Bitslip bit.
// Bit [6:2]: Delay (MSB first)
// Bit [38:7]: Channel select (MSB first).
// Bit [70:39]: Bit select (MSB first).
//
// "MSB first" means that:
// - the delay_reg shift reg needs to shift LEFT each cycle (shift out the MSB first)
// - the bit/chan shift regs need to shift RIGHT each cycle (bit[31] selected shifted out first)
//
// Synthesis should recognize that you can just invert the address and use an SRL to generate
// this - if not we can flip it ourselves.
//
// Note: synthesis is stupid, we need to do this ourselves. Sigh.
module RITC_bit_control_loader(
		input [3:0] bit_addr_i,
		input [2:0] chan_addr_i,
		input [4:0] delay_i,
		input bitslip_i,
		input load_i,
		input clk_i,
		output ctrl_o,
		output busy_o
    );
	reg start_bit = 0;
	reg bitslip_reg = 0;
	reg [4:0] delay_reg = {5{1'b0}};
	reg select_bit_output = 0;
	
	//% Indicates which channel is selected.
	wire channel_output;
	//% Indicates which bit is selected.
	wire bit_output;
	
	// Bit broadcasting is a bit difficult - you need to make sure that the output is terminated after fully going through
	// the bit SRL.
	
    //% Indicates a broadcast delay (every bit in the channel). 15 is used by clock's input, 14 is used by VCDL. 
    wire bit_broadcast = (bit_addr_i == 4'd13);
	
	//% Muxed bit output
	wire muxed_bit_output = (bit_broadcast) ? 1'b1 : bit_output;
	
	//% Cascade output of the channel SRL.
	wire channel_cascade_out;
	
	//% Cascade output of the bit SRL.
	wire bit_cascade_out;
	
	//% Address for the bit SRL: 31->0, 30->1, 29->2, etc. This is equivalent to a complete inversion.
	wire [4:0] bit_address = {1'b1, ~bit_addr_i};
	
	//% Address for the channel SRL: 31->0, 30->1, etc. Again a bit inversion.
	wire [4:0] chan_address = {2'b11, ~chan_addr_i};
	
	//% Indicates loader is busy
	reg busy = 0;
	
	SRLC32E u_chan_srl(.D(bitslip_i || load_i),.A(chan_address),.CE(1'b1),.CLK(clk_i),.Q(channel_output),.Q31(channel_cascade_out));
	SRLC32E u_bit_srl(.D(channel_cascade_out),.A(bit_address),.CE(1'b1),.CLK(clk_i),.Q(bit_output),.Q31(bit_cascade_out));
	
	always @(posedge clk_i) begin
		if (bitslip_i || load_i) start_bit <= 1;
		else start_bit <= bitslip_reg;
		
		if (bitslip_i) bitslip_reg <= 1;
		else bitslip_reg <= delay_reg[4];
		
		if (load_i) delay_reg <= delay_i;
		else delay_reg <= {delay_reg[3:0],(select_bit_output ? muxed_bit_output : channel_output)};
		
		// When the bit fully propagates through the bit SRL, jump back to the channel input. This also terminates the SRL with the right length
		// for bit broadcasting.
		if (load_i || bitslip_i || bit_cascade_out) select_bit_output <= 0;
		else if (channel_cascade_out) select_bit_output <= 1;

        if (bitslip_i || load_i) busy <= 1;
        else if (bit_cascade_out) busy <= 0;
	end
		
	assign ctrl_o = start_bit;
	assign busy_o = busy;
endmodule
