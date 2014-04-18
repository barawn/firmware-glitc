`ifndef GLITC_MACROS_VH
`define GLITC_MACROS_VH
// Map a correlation. Before this is used, macros
// `CMAP_INPUT_PREFIX and `CMAP_SR_PREFIX must be defined.
`define CMAP16(name, corrnum, bit_start) \
	`ifdef CMAP16_STAGE_START             \
	`undef CMAP16_STAGE_START             \
	`endif                                \
	`ifdef CMAP16_BIT_START               \
	`undef CMAP16_BIT_START               \
	`endif                                \
	`define CMAP16_STAGE_START ( bit_start / 16 ) \
	`define CMAP16_BIT_START ( bit_start % 16 )   \
	assign `CMAP_INPUT_PREFIX(name) [ corrnum ] [ 00 ] = `CMAP_SR_PREFIX(name) [ ( `CMAP16_BIT_START + 0 ) % 16 ] [ ( `CMAP16_STAGE_START + (( `CMAP16_BIT_START + 0 )/16))] ; \
	assign `CMAP_INPUT_PREFIX(name) [ corrnum ] [ 01 ] = `CMAP_SR_PREFIX(name) [ ( `CMAP16_BIT_START + 1 ) % 16 ] [ ( `CMAP16_STAGE_START + (( `CMAP16_BIT_START + 1 )/16))] ; \
	assign `CMAP_INPUT_PREFIX(name) [ corrnum ] [ 02 ] = `CMAP_SR_PREFIX(name) [ ( `CMAP16_BIT_START + 2 ) % 16 ] [ ( `CMAP16_STAGE_START + (( `CMAP16_BIT_START + 2 )/16))] ; \
	assign `CMAP_INPUT_PREFIX(name) [ corrnum ] [ 03 ] = `CMAP_SR_PREFIX(name) [ ( `CMAP16_BIT_START + 3 ) % 16 ] [ ( `CMAP16_STAGE_START + (( `CMAP16_BIT_START + 3 )/16))] ; \
	assign `CMAP_INPUT_PREFIX(name) [ corrnum ] [ 04 ] = `CMAP_SR_PREFIX(name) [ ( `CMAP16_BIT_START + 4 ) % 16 ] [ ( `CMAP16_STAGE_START + (( `CMAP16_BIT_START + 4 )/16))] ; \
	assign `CMAP_INPUT_PREFIX(name) [ corrnum ] [ 05 ] = `CMAP_SR_PREFIX(name) [ ( `CMAP16_BIT_START + 5 ) % 16 ] [ ( `CMAP16_STAGE_START + (( `CMAP16_BIT_START + 5 )/16))] ; \
	assign `CMAP_INPUT_PREFIX(name) [ corrnum ] [ 06 ] = `CMAP_SR_PREFIX(name) [ ( `CMAP16_BIT_START + 6 ) % 16 ] [ ( `CMAP16_STAGE_START + (( `CMAP16_BIT_START + 6 )/16))] ; \
	assign `CMAP_INPUT_PREFIX(name) [ corrnum ] [ 07 ] = `CMAP_SR_PREFIX(name) [ ( `CMAP16_BIT_START + 7 ) % 16 ] [ ( `CMAP16_STAGE_START + (( `CMAP16_BIT_START + 7 )/16))] ; \
	assign `CMAP_INPUT_PREFIX(name) [ corrnum ] [ 08 ] = `CMAP_SR_PREFIX(name) [ ( `CMAP16_BIT_START + 8 ) % 16 ] [ ( `CMAP16_STAGE_START + (( `CMAP16_BIT_START + 8 )/16))] ; \
	assign `CMAP_INPUT_PREFIX(name) [ corrnum ] [ 09 ] = `CMAP_SR_PREFIX(name) [ ( `CMAP16_BIT_START + 9 ) % 16 ] [ ( `CMAP16_STAGE_START + (( `CMAP16_BIT_START + 9 )/16))] ; \
	assign `CMAP_INPUT_PREFIX(name) [ corrnum ] [ 10 ] = `CMAP_SR_PREFIX(name) [ ( `CMAP16_BIT_START + 10 ) % 16 ] [ ( `CMAP16_STAGE_START + (( `CMAP16_BIT_START + 10 )/16))] ; \
	assign `CMAP_INPUT_PREFIX(name) [ corrnum ] [ 11 ] = `CMAP_SR_PREFIX(name) [ ( `CMAP16_BIT_START + 11 ) % 16 ] [ ( `CMAP16_STAGE_START + (( `CMAP16_BIT_START + 11 )/16))] ; \
	assign `CMAP_INPUT_PREFIX(name) [ corrnum ] [ 12 ] = `CMAP_SR_PREFIX(name) [ ( `CMAP16_BIT_START + 12 ) % 16 ] [ ( `CMAP16_STAGE_START + (( `CMAP16_BIT_START + 12 )/16))] ; \
	assign `CMAP_INPUT_PREFIX(name) [ corrnum ] [ 13 ] = `CMAP_SR_PREFIX(name) [ ( `CMAP16_BIT_START + 13 ) % 16 ] [ ( `CMAP16_STAGE_START + (( `CMAP16_BIT_START + 13 )/16))] ; \
	assign `CMAP_INPUT_PREFIX(name) [ corrnum ] [ 14 ] = `CMAP_SR_PREFIX(name) [ ( `CMAP16_BIT_START + 14 ) % 16 ] [ ( `CMAP16_STAGE_START + (( `CMAP16_BIT_START + 14 )/16))] ; \
	assign `CMAP_INPUT_PREFIX(name) [ corrnum ] [ 15 ] = `CMAP_SR_PREFIX(name) [ ( `CMAP16_BIT_START + 15 ) % 16 ] [ ( `CMAP16_STAGE_START + (( `CMAP16_BIT_START + 15 )/16))] 


// Flattens an array of 16 "bits"-bit entries into a 16*bits vector.
// "in" is the input array, out is the output vector.
`define VEC16( in , out , bits ) \
	assign out [00*bits +: bits] = in [ 00 ];  \
	assign out [01*bits +: bits] = in [ 01 ];  \
	assign out [02*bits +: bits] = in [ 02 ];  \
	assign out [03*bits +: bits] = in [ 03 ];  \
	assign out [04*bits +: bits] = in [ 04 ];  \
	assign out [05*bits +: bits] = in [ 05 ];  \
	assign out [06*bits +: bits] = in [ 06 ];  \
	assign out [07*bits +: bits] = in [ 07 ];  \
	assign out [08*bits +: bits] = in [ 08 ];  \
	assign out [09*bits +: bits] = in [ 09 ];  \
	assign out [10*bits +: bits] = in [ 10 ];  \
	assign out [11*bits +: bits] = in [ 11 ];  \
	assign out [12*bits +: bits] = in [ 12 ];  \
	assign out [13*bits +: bits] = in [ 13 ];  \
	assign out [14*bits +: bits] = in [ 14 ];  \
	assign out [15*bits +: bits] = in [ 15 ]

`endif
