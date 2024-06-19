`timescale 1ns/10ps

`define CYCLE 12.16 // Modify your clock period here !!

`define MAX_CYCLE_PER_PATTERN 50000

`define PatternPATH "../../pattern/"  // Open in Quartus

// `define PatternPATH "./pattern/"      // Open in Modelsim

`define printMap 0 // You can set it to 1 to print out the map

module tb_Laser;

parameter pat_number = 6;

integer fd;
string  line;

logic        CLK;
logic        RST;
logic [3:0]    X;
logic [3:0]    Y;
logic      valid;
logic [3:0]  C1X;
logic [3:0]  C1Y;
logic [3:0]  C2X;
logic [3:0]  C2Y;
logic       DONE;

initial CLK = 0;
initial RST = 0;

Laser UUT(
  .CLK  (  CLK),
  .RST  (  RST),
  .X    (    X),
  .Y    (    Y),
  .valid(valid),
  .C1X  (  C1X),
  .C1Y  (  C1Y),
  .C2X  (  C2X),
  .C2Y  (  C2Y),
  .DONE ( DONE)
);

always begin #(`CYCLE/2) CLK = ~CLK; end


string PAT [pat_number] = {"img1.pattern",
                           "img2.pattern",
                           "img3.pattern",
                           "img4.pattern",
                           "img5.pattern",
                           "img6.pattern"
                          };


parameter ST_RESET   = 0, 
          ST_PATTERN = 1, 
          ST_RUN     = 2, 
          ST_RETURN  = 3;

logic [1:0] state = 0;
logic unsigned [1:0] rst_count = 0;
logic unsigned [5:0] pixel_count = 0;
int pat_n;
logic [30:0] cycle_pat = 0;
logic [30:0] cycle_total = 0;


initial begin
    state <= ST_RESET;
    rst_count <= 0;
    pat_n <= 0;
    valid <= 0;
end

integer i;
integer charcount;
integer freturn;
integer optmax[pat_number] ;
integer PX [pat_number][40];
integer PY [pat_number][40];
integer j;                  
integer RET_C1X[pat_number];
integer RET_C1Y[pat_number];
integer RET_C2X[pat_number];
integer RET_C2Y[pat_number];

initial begin
    for(i=0;i<pat_number;i=i+1) begin
        fd = $fopen({`PatternPATH, PAT[i]},"r");
        if (fd == 0) begin
            $display ("Failed open %s",PAT[i]);
            $finish;
        end
        else begin
            charcount = $fgets (line, fd);
            while(charcount > 0) begin: READ_PATTERN
                while((line == "\n") || (line.substr(1, 2) == "//")) charcount = $fgets (line, fd);
                if(charcount == 0 ) disable READ_PATTERN ;
                if( line.substr(0, 6) == "optimum") begin
                    freturn = $sscanf(line, "optimum=%d",optmax[i]);
                    j = 0;
                end
                else begin
                    freturn = $sscanf(line,"%d %d",PX[i][j],PY[i][j]);
                    j = j + 1;
                end
                charcount = $fgets (line, fd);
            end

        end
        $fclose(fd);
    end
end

always @(posedge CLK) cycle_total = cycle_total + 1;

integer cover_sum = 0;
integer total_cover_sum = 0;
integer optimum_sum = 0;
integer d1 = 0;
integer d2 = 0;
integer wait_done = 0;

assign X = (pixel_count <= 40 && valid)?(PX[pat_n][pixel_count-1]):('dz);
assign Y = (pixel_count <= 40 && valid)?(PY[pat_n][pixel_count-1]):('dz);

always @(posedge CLK ) begin
    case(state)
        ST_RESET: begin
            if (rst_count == 2) begin
                #1 RST <= 1'b0;
                rst_count <= 0;
                state <=ST_PATTERN;
            end 
            else begin
                #1 RST <= 1'b1;
                rst_count <= rst_count+1;
                pixel_count <= 0;
                wait_done <= 0;
            end
        end
        ST_PATTERN: begin
            if(DONE == 0) begin 
                if (pixel_count < 40) begin
                    if({$random} % 1000 >= 800)begin
                      #(`CYCLE/2.0);
                      pixel_count <= pixel_count + 1;
                      valid <= 1'b1;
                    end
                    else begin
                      #(`CYCLE/2.0);
                      valid <= 1'b0;
                    end
                end
                else begin
                    state <= ST_RUN;
                    cycle_pat <= 0;
                    #(`CYCLE/2.0);
                    valid <= 1'b0;
                end
            end
            else begin
                valid <= 1'b0;
                if (pixel_count == 0) begin
                    if(DONE === 1'bx) begin
                        $display("\n%10t , ERROR, DONE is in unknown state. Simlation terminated\n",$time);
                        $finish;
                    end
                    else begin
                        #1;
                        $display("%10t , please pull down signal DONE",$time);
                        wait_done <= wait_done + 1;
                        if(wait_done > 10) begin
                            $display("\n%t , ERROR, please pull down signal DONE. Simlation terminated\n",$time);
                            $finish;
                        end
                    end
                end
                else begin
                $display("\n%10t, ERROR, received DONE while send pattern, %s %3d pixel. Simlation terminated\n",$time, PAT[pat_n],pixel_count);
                $finish;
                end
            end
        end
        ST_RUN: begin
            if(DONE == 0) begin 
                cycle_pat <= cycle_pat + 1;
                if (cycle_pat > `MAX_CYCLE_PER_PATTERN) begin
                    $display("======================== PATTERN %s ========================",PAT[pat_n]);
                    $display("-- Max cycle pre pattern reached, force output result C1(%2d,%2d),C2(%2d,%2d) --",C1X,C1Y,C2X,C2Y);
                    count_cover(C1X,C1Y,C2X,C2Y,cover_sum,total_cover_sum,optimum_sum);
                    if(`printMap)draw_img(C1X,C1Y,C2X,C2Y,pat_n);
                    RET_C1X[pat_n] <= C1X;
                    RET_C1Y[pat_n] <= C1Y;
                    RET_C2X[pat_n] <= C2X;
                    RET_C2Y[pat_n] <= C2Y;
                    if (pat_n < pat_number-1) begin
                        pat_n <= pat_n+1;
                        pixel_count <= 0;
                        rst_count <= 0;
                        state <= ST_RESET;
                    end
                    else begin
                     $display ("");
                     $display("Your clock period: %.2f ns", `CYCLE);
                     $display ("*******************************");
                     $display ("**   Finish Simulation       **");
                     $display ("**   RUN CYCLE = %6d      **"   ,cycle_total);
                     $display ("**   RUN TIME  = %7d ns  **"   ,cycle_total * `CYCLE);
                     $display ("**   Cover total = %3d/%3d   **", total_cover_sum,optimum_sum);
                     $display ("*******************************");
                     $finish;
                    end
                end
            end
            else begin
                $display("======================== PATTERN %s ========================",PAT[pat_n]);
                $display("---- Used Cycle: %10d ----",cycle_pat);
                $display("---- Get Return: C1(%2d,%2d),C2(%2d,%2d) ----",C1X,C1Y,C2X,C2Y);
                
                count_cover(C1X,C1Y,C2X,C2Y,cover_sum,total_cover_sum,optimum_sum);
                if(`printMap)draw_img(C1X,C1Y,C2X,C2Y,pat_n);
                
                RET_C1X[pat_n]<=C1X;
                RET_C1Y[pat_n]<=C1Y;
                RET_C2X[pat_n]<=C2X;
                RET_C2Y[pat_n]<=C2Y;

                if (pat_n < pat_number-1) begin
                    pat_n <= pat_n + 1;
                    pixel_count <= 0;
                    state <= ST_PATTERN;
                end
                else begin
                 $display ("");
                 $display("Your clock period: %.2f ns", `CYCLE);
                 $display ("*******************************");
                 $display ("**   Finish Simulation       **");
                 $display ("**   RUN CYCLE = %6d      **"   ,cycle_total);
                 $display ("**   RUN TIME  = %7d ns  **"   ,cycle_total * `CYCLE);
                 $display ("**   Cover total = %3d/%3d   **", total_cover_sum,optimum_sum);
                 $display ("*******************************");
                 $finish;
                end
                if(pat_n % 2 == 0)resetTask();
            end
        end
        default:begin
        end
    endcase
end


initial begin
    $display("********************************");
    $display("**      Simulation Start      **");
    $display("********************************");
end

task count_cover;
    input [3:0] C1X;
    input [3:0] C1Y;
    input [3:0] C2X;
    input [3:0] C2Y;
    output integer cover_sum;
    inout integer total_cover_sum;
    inout integer optimum_sum;
    cover_sum = 0;
    for(i = 0;i < 40;i = i + 1) begin
        if ((^C1X === 1'bx) || (^C1Y  === 1'bx)) begin
            d1 = 100;
        end
        else begin
            d1 = (C1X-PX[pat_n][i])**2+(C1Y-PY[pat_n][i])**2;
        end
        if ((^C2X === 1'bx) || (^C2Y  === 1'bx)) begin
            d2 = 100;
        end
        else begin
            d2 = (C2X-PX[pat_n][i])**2+(C2Y-PY[pat_n][i])**2;
        end
        if((d1 <= 16) || (d2 <= 16)) begin
            cover_sum = cover_sum + 1;
        end
    end
    total_cover_sum = total_cover_sum + cover_sum;
    optimum_sum = optimum_sum+optmax[pat_n];
    $display("---- cover = %3d, optimum = %3d", cover_sum, optmax[pat_n]);
endtask

task draw_img;
    input [3:0] C1X;
    input [3:0] C1Y;
    input [3:0] C2X;
    input [3:0] C2Y;
    input integer pat_n;
    string IMG [128][128];
    for(j=0;j<16;j=j+1) begin
        for(i=0;i<16;i=i+1) begin
            IMG[i][j] = "-";
        end
    end
    IMG[C1X][C1Y] = "*";
    IMG[C2X][C2Y] = "*";

    for(i = 0;i < 40;i = i + 1) begin
        if ((^C1X === 1'bx) || (^C1Y  === 1'bx)) begin
            d1 = 100;
        end
        else begin
            d1 = (C1X-PX[pat_n][i])**2+(C1Y-PY[pat_n][i])**2;
        end
        if ((^C2X === 1'bx) || (^C2Y  === 1'bx)) begin
            d2 = 100;
        end
        else begin
            d2 = (C2X-PX[pat_n][i])**2+(C2Y-PY[pat_n][i])**2;
        end
        if((d1 <= 16) || (d2 <= 16)) begin
            IMG[PX[pat_n][i]][PY[pat_n][i]] = "x";
            if((PX[pat_n][i] == C1X) && (PY[pat_n][i] == C1Y)) begin
                IMG[PX[pat_n][i]][PY[pat_n][i]] = "X";
            end
            if((PX[pat_n][i] == C2X) && (PY[pat_n][i] == C2Y)) begin
                IMG[PX[pat_n][i]][PY[pat_n][i]] = "X";
            end
        end
        else begin
            IMG[PX[pat_n][i]][PY[pat_n][i]] = "+";
        end
    end
    $display("   0 1 2 3 4 5 6 7 8 9 a b c d e f");
    for(j=0;j<16;j=j+1) begin
        $write(" %1x",j);
        for(i=0;i<16;i=i+1) begin
            `ifdef USECOLOR
                case(IMG[i][j])
                   "+": begin
                       $write("%c[1;34m",27);
                       $write("%2s",IMG[i][j]);
                       $write("%c[0m",27);
                        end
                   "x": begin
                       $write("%c[1;31m",27);
                       $write("%2s",IMG[i][j]);
                       $write("%c[0m",27);
                        end
                   "*": begin
                       $write("%c[1;32m",27);
                       $write("%2s",IMG[i][j]);
                       $write("%c[0m",27);
                        end
                   "X": begin
                       $write("%c[1;32m",27);
                       $write("%2s",IMG[i][j]);
                       $write("%c[0m",27);
                        end
                   default: begin
                       $write("%2s",IMG[i][j]);
                        end
                endcase

            `else
                $write("%2s",IMG[i][j]);
            `endif
        end
        $write("\n");
    end
    $write("\n");
endtask



task resetTask;
begin
  RST = 1;
  repeat(3)@(posedge CLK)RST = 1;
  RST = 0;
end
endtask

endmodule

