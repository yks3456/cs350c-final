/* memory */

`timescale 1ps/1ps

// Protocol:
//  set readEnable = 1
//      raddr = read address
//
//  A few cycles later:
//      ready = 1
//      rdata = data
//
module mem(input clk,
    // read port
    input readEnable,
    input [15:0]raddr,
    output ready,
    output [15:0]rdata,
    input readEnable2,
    input [15:0]raddr2,
    output ready2,
    output [15:0]rdata2,
    input [15:0]waddr,
    input writeEnable,
    input [15:0]wdata,
    input [15:0]waddr2,
    input writeEnable2,
    input [15:0]wdata2
   );

    reg [15:0]data[1023:0];
    reg [15:0]ptr = 16'hxxxx;
    reg [15:0]ptr2 = 16'hxxxx;

    /* Simulation -- read initial content from file */
    initial begin
        $readmemh("mem.hex",data);
    end

    reg [15:0]counter = 0;
    reg [15:0]counter2 = 0;
    reg [15:0]temp;
    reg [15:0]temp2;

    assign ready = (counter == 1);
    assign rdata = (counter == 1) ? temp : 16'hxxxx;

    assign ready2 = (counter2 == 1);
    assign rdata2 = (counter2 == 1) ? temp2 : 16'hxxxx;

    always @(posedge clk) begin
        if (readEnable) begin
            temp <= data[raddr];
            ptr <= raddr;
            counter <= 100;
        end else begin
            if (counter > 0) begin
                counter <= counter - 1;
            end else begin
                ptr <= 16'hxxxx;
            end
        end

        if (readEnable2) begin
            temp2 <= data[raddr2];
            ptr2 <= raddr2;
            counter2 <= 100;
        end else begin
            if (counter2 > 0) begin
                counter2 <= counter2 - 1;
            end else begin
                ptr2 <= 16'hxxxx;
            end
        end

        if (writeEnable) begin
            data[waddr] <= wdata;
            $display("Core 1: #mem[0x%x] <= 0x%x",waddr,wdata);
        end

        if (writeEnable2) begin
            data[waddr2] <= wdata2;
            $display("Core 2: #mem[0x%x] <= 0x%x",waddr2,wdata2);
        end
    end

endmodule
