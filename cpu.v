`timescale 1ps/1ps

//
// This is an inefficient implementation.
//   make it run correctly in less cycles, fastest implementation wins
//

//
// States:
//

// Fetch
`define F0 0
`define F2 2

// decode
`define D0 3

// load
`define L0 4
`define L2 6

// write-back
`define WB 7

// regs
`define R0 8
`define R1 9

// execute
`define EXEC 10

// halt
`define HALT 15

module main();
    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(1,core1);
        $dumpvars(1,core2);
        $dumpvars(1,i0);
        $dumpvars(1,main);
    end

    wire [15:0]core1memIn;
    wire [15:0]core1memOut;
    wire [3:0]core1state;
    wire core1memReady;
    wire [15:0]core2memIn;
    wire [15:0]core2memOut;
    wire [3:0]core2state;
    wire core2memReady;
    wire clk;
    wire [15:0]core1startPC = 16'h0000;
    wire [15:0]core2startPC = 16'h000E;
    reg corenumber = 0;
    reg corenumber2 = 1;
    wire atomic1;
    wire atomic2;
    wire core1we;
    wire core2we;
    wire [15:0]wdata1;
    wire [15:0]wdata2;
    wire [15:0]waddr1;
    wire [15:0]waddr2;


    clock c0(clk);
    cpu core1(clk, corenumber, core1startPC, core1memOut, core1memIn, core1state, core1memReady, atomic1, atomic2, waddr1, wdata1, core1we, core2we, waddr2);
    cpu core2(clk, corenumber2, core2startPC, core2memOut, core2memIn, core2state, core2memReady, atomic2, atomic1, waddr2, wdata2, core2we, core1we, waddr1);

    mem i0(clk,
       (core1state == `F0) || (core1state == `L0),
       core1memIn,
       core1memReady,
       core1memOut,
       (core2state == `F0) || (core2state == `L0),
       core2memIn,
       core2memReady,
       core2memOut,
       waddr1,
       core1we,
       wdata1,
       waddr2,
       core2we,
       wdata2
       );

endmodule

module cpu(input clk, input corenumber, input [15:0]startPC, input [15:0]memOutput, output [15:0]memInput, output [3:0]corestate, input memR, output atomicinst, input atomicpause, output [15:0]waddr, output [15:0]wdata, output we, input ocwe, input [15:0]ocwa);

    initial begin
//        $dumpfile("cpu.vcd");
//        $dumpvars(1,main);
//        $dumpvars(1,i0);
        pc <= startPC;

        icache_v[0] = 0;
        icache_v[1] = 0;
        icache_v[2] = 0;
        icache_v[3] = 0;

        dcache_v[0] = 0;
        dcache_v[1] = 0;
        dcache_v[2] = 0;
        dcache_v[3] = 0;

        icache_e[0] = 0;
        icache_e[1] = 0;
        icache_e[2] = 0;
        icache_e[3] = 0;

        dcache_e[0] = 0;
        dcache_e[1] = 0;
        dcache_e[2] = 0;
        dcache_e[3] = 0;
    end

    // clock
//    wire clk;
//    clock c0(clk);

    reg [3:0]state = `F0;

    //cache
    wire [3:0]icachehit = (icache_v[0] && icachetag[0] == pc) ? 0 :
                          (icache_v[1] && icachetag[1] == pc) ? 1 :
                          (icache_v[2] && icachetag[2] == pc) ? 2 :
                          (icache_v[3] && icachetag[3] == pc) ? 3 :
                          4;
    wire [3:0]icacheempty = (~icache_v[0]) ? 0 :
                            (~icache_v[1]) ? 1 :
                            (~icache_v[2]) ? 2 :
                            (~icache_v[3]) ? 3 :
                            4;
    wire [2:0]evicticache = (icache_v[0] && icache_e[0] == 3) ? 0 :
                            (icache_v[1] && icache_e[1] == 3) ? 1 :
                            (icache_v[2] && icache_e[2] == 3) ? 2 :
                            (icache_v[3] && icache_e[3] == 3) ? 3 :
                            0;

    wire [3:0]dcachehit = (dcache_v[0] && dcachetag[0] == res) ? 0 :
                          (dcache_v[1] && dcachetag[1] == res) ? 1 :
                          (dcache_v[2] && dcachetag[2] == res) ? 2 :
                          (dcache_v[3] && dcachetag[3] == res) ? 3 :
                          4;
    wire [3:0]dcacheempty = (~dcache_v[0]) ? 0 :
                            (~dcache_v[1]) ? 1 :
                            (~dcache_v[2]) ? 2 :
                            (~dcache_v[3]) ? 3 :
                            4;
    wire [2:0]evictdcache = (dcache_v[0] && dcache_e[0] == 3) ? 0 :
                            (dcache_v[1] && dcache_e[1] == 3) ? 1 :
                            (dcache_v[2] && dcache_e[2] == 3) ? 2 :
                            (dcache_v[3] && dcache_e[3] == 3) ? 3 :
                            0;

    reg [15:0]icache[3:0];
    reg [15:0]dcache[3:0];

    reg [15:0]icachetag[3:0];
    reg [15:0]dcachetag[3:0];

    reg icache_v[3:0];
    reg dcache_v[3:0];
    reg [1:0]icache_e[3:0];
    reg [1:0]dcache_e[3:0];

    // PC
    reg [15:0]pc;// = startPC;

    // fetch 
    wire [15:0]memOut;
    wire memReady;
    wire [15:0]memIn = (state == `F0) ? pc :
                       (state == `L0) ? res :
                       16'hxxxx;


    assign memInput = memIn;
    assign memOut = memOutput;
    assign corestate = state;
    assign memReady = memR;

//    mem i0(clk,
//       (state == `F0) || (state == `L0),
//       memIn,
//       memReady,
//       memOut);

    reg [15:0]inst;

    // decode
    wire [3:0]opcode = inst[15:12];
    wire [3:0]ra = inst[11:8];
    wire [3:0]rb = inst[7:4];
    wire [3:0]rt = inst[3:0];
    wire [15:0]jjj = inst[11:0]; // zero-extended
    wire [15:0]ii = inst[11:4]; // zero-extended
    wire [15:0]kk = inst[7:0];

    wire [15:0]va;
    wire [15:0]vb;

    reg [15:0]res; // what to write in the register file

    reg atomic = 0;
    assign atomicinst = atomic;
    reg [15:0]writeaddress;
    reg [15:0]writedata;
    reg writeEnable;
    assign waddr = writeaddress;
    assign wdata = writedata;
    assign we = writeEnable;

    // registers
    regs rf(clk, corenumber,
        (state == `R0), ra, va,
        (state == `R0), rb, vb, 
        (state == `WB), rt, res);

    always @(posedge clk) begin
        writeEnable <= 0;
        if(ocwe) begin
            if(icachetag[0] == ocwa) begin
                icache_v[0] <= 0;
            end
            if(icachetag[1] == ocwa) begin
                icache_v[1] <= 0;
            end
            if(icachetag[2] == ocwa) begin
                icache_v[2] <= 0;
            end
            if(icachetag[3] == ocwa) begin
                icache_v[3] <= 0;
            end
            if(dcachetag[0] == ocwa) begin
                dcache_v[0] <= 0;
            end
            if(dcachetag[1] == ocwa) begin
                dcache_v[1] <= 0;
            end
            if(dcachetag[2] == ocwa) begin
                dcache_v[2] <= 0;
            end
            if(dcachetag[3] == ocwa) begin
                dcache_v[3] <= 0;
            end
        end
        if(~atomicpause) begin
        case(state)
        `F0: begin
            writeEnable <= 0;
            if(icachehit != 4) begin
                inst <= icache[icachehit];
                state <= `D0;

                if(icachehit != 0 && icache_e[0] <= icache_e[icachehit]) begin
                    icache_e[0] <= icache_e[0]+1;
                end
                if(icachehit != 1 && icache_e[1] <= icache_e[icachehit]) begin
                    icache_e[1] <= icache_e[1]+1;
                end
                if(icachehit != 2 && icache_e[2] <= icache_e[icachehit]) begin
                    icache_e[2] <= icache_e[2]+1;
                end
                if(icachehit != 3 && icache_e[3] <= icache_e[icachehit]) begin
                    icache_e[3] <= icache_e[3]+1;
                end

                icache_e[icachehit] <= 0;
            end
            else begin
                state <= `F2;
            end
        end
        `F2: begin
//            if(icachehit != 4) begin
//                state <= `D0;
//            end
//            else begin
                if (memReady) begin
                    if(icacheempty != 4) begin
                        icachetag[icacheempty] <= pc;
                        icache[icacheempty] <= memOut;
                        icache_v[icacheempty] <= 1;
                    end
                    else begin
                        icachetag[evicticache] <= pc;
                        icache[evicticache] <= memOut;

                        if(evicticache == 0) begin
                            icache_e[1] <= icache_e[1]+1;
                            icache_e[2] <= icache_e[2]+1;
                            icache_e[3] <= icache_e[3]+1;
                            icache_e[0] <= 0;
                        end
                        if(evicticache == 1) begin
                            icache_e[0] <= icache_e[1]+1;
                            icache_e[2] <= icache_e[2]+1;
                            icache_e[3] <= icache_e[3]+1;
                            icache_e[1] <= 0;
                        end
                        if(evicticache == 2) begin
                            icache_e[0] <= icache_e[1]+1;
                            icache_e[1] <= icache_e[2]+1;
                            icache_e[3] <= icache_e[3]+1;
                            icache_e[2] <= 0;
                        end
                        if(evicticache == 3) begin
                            icache_e[0] <= icache_e[1]+1;
                            icache_e[1] <= icache_e[2]+1;
                            icache_e[2] <= icache_e[3]+1;
                            icache_e[3] <= 0;
                        end
                    end
                    state <= `D0;
                    inst <= memOut;
                end
//            end
        end
        `D0: begin
            case(opcode)
            4'h0 : begin // mov
                res <= ii;
                state <= `WB;
            end
            4'h1 : begin // add
                state <= `R0;
            end
            4'h2 : begin // jmp
                pc <= jjj;
                state <= `F0;
            end
            4'h3 : begin // halt
                state <= `HALT;
            end
            4'h4 : begin // ld
                res <= ii;
                state <= `L0;
            end
            4'h5 : begin // ldr
                state <= `R0;
            end
            4'h6 : begin // jeq
                state <= `R0;
            end
            4'h7 : begin // st
                writeaddress <= kk;
                state <= `R0;
            end
            4'h8 : begin // test_and_set
                atomic <= 1;
                res <= ii;
                state <= `L0;
            end
            default: begin
                $display("unknown inst %x @ %x",inst,pc);
                pc <= pc + 1;
                state <= `F0;
            end
            endcase        
        end
        `WB: begin
            pc <= pc + 1;
            if(~res && opcode == 4'h8) begin
                writedata <= 1;
                writeaddress <= ii;
                writeEnable <= 1;
            end
            state <= `F0;
        end
        `L0: begin
            if(dcachehit != 4) begin
                res <= dcache[dcachehit];

                if(dcachehit != 0 && dcache_e[0] <= dcache_e[dcachehit]) begin
                    dcache_e[0] <= dcache_e[0]+1;
                end
                if(dcachehit != 1 && dcache_e[1] <= dcache_e[dcachehit]) begin
                    dcache_e[1] <= dcache_e[1]+1;
                end
                if(dcachehit != 2 && dcache_e[2] <= dcache_e[dcachehit]) begin
                    dcache_e[2] <= dcache_e[2]+1;
                end
                if(dcachehit != 3 && dcache_e[3] <= dcache_e[dcachehit]) begin
                    dcache_e[3] <= dcache_e[3]+1;
                end
                if(opcode == 4'h8 && res != 1 && res != 0) begin
                    res <= 0;
                end
                state <= `WB;
            end
            else begin
                state <= `L2;
            end
        end
        `L2: begin
                if (memReady) begin
                    if(dcacheempty != 4) begin
                        dcachetag[dcacheempty] <= res;
                        dcache[dcacheempty] <= memOut;
                        dcache_v[dcacheempty] <= 1;
                    end
                    else begin
                        dcachetag[evictdcache] <= res;
                        dcache[evictdcache] <= memOut;

                        if(evictdcache == 0) begin
                            dcache_e[1] <= dcache_e[1]+1;
                            dcache_e[2] <= dcache_e[2]+1;
                            dcache_e[3] <= dcache_e[3]+1;
                            dcache_e[0] <= 0;
                        end
                        if(evictdcache == 1) begin
                            dcache_e[0] <= dcache_e[1]+1;
                            dcache_e[2] <= dcache_e[2]+1;
                            dcache_e[3] <= dcache_e[3]+1;
                            dcache_e[1] <= 0;
                        end
                        if(evictdcache == 2) begin
                            dcache_e[0] <= dcache_e[1]+1;
                            dcache_e[1] <= dcache_e[2]+1;
                            dcache_e[3] <= dcache_e[3]+1;
                            dcache_e[2] <= 0;
                        end
                        if(evictdcache == 3) begin
                            dcache_e[0] <= dcache_e[1]+1;
                            dcache_e[1] <= dcache_e[2]+1;
                            dcache_e[2] <= dcache_e[3]+1;
                            dcache_e[3] <= 0;
                        end
                    end
                    if(opcode == 4'h8 && res != 1 && res != 0) begin
                        res <= 0;
                    end
                    else begin
                        res <= memOut;
                    end
                    state <= `WB;
                end
           /* if (memReady) begin
                state <= `WB;
                res <= memOut;
            end*/
        end
        `R0: begin
            state <= `R1;
        end
        `R1: begin
            state <= `EXEC;
        end
        `EXEC : begin
            case (opcode)
                4'h1 : begin // add
                    res <= va + vb;
                    state <= `WB;
                end
                4'h5 : begin // ldr
                    res <= va + vb;
                    state <= `L0;
                end
                4'h6 : begin // jeq
                    pc <= pc + ((va == vb) ? inst[3:0] : 1);
                    state <= `F0;
                end
                4'h7 : begin // st
                    writedata <= va;
                    writeEnable <= 1;
                    pc <= pc + 1;
                    state <= `F0;
                end
                default: begin
                    $display("invalid opcode in exec %d",opcode);
                    $finish;
                end
            endcase
        end
        `HALT: begin
            $finish;
        end
        default: begin
            $display("unknown state %d",state);
            $finish;
        end
        endcase
        end
    end

endmodule
