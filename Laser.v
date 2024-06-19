module chk_in_circle (
  input       [3:0] abs_x,
  input       [3:0] abs_y,
  output  reg   in_circle
);

always @(*) begin
  case ({abs_x, abs_y})
    {4'd0,4'd4}: in_circle = 1'b1;
    {4'd0,4'd3},{4'd1,4'd3},{4'd2,4'd3}: in_circle = 1'b1;
    {4'd0,4'd2},{4'd1,4'd2},{4'd2,4'd2},{4'd3,4'd2}: in_circle = 1'b1;
    {4'd0,4'd1},{4'd1,4'd1},{4'd2,4'd1},{4'd3,4'd1}: in_circle = 1'b1;
    {4'd0,4'd0},{4'd1,4'd0},{4'd2,4'd0},{4'd3,4'd0},{4'd4,4'd0}: in_circle = 1'b1;
    default: in_circle = 1'b0;
  endcase
end
  
endmodule

module countonebits (
  input         [4:0]   list,
  input         [4:0]   mask,
  output  reg   [2:0] amount
);

always @(*) begin
  case (list & mask)
    5'b00000: amount = 0;
    5'b00001: amount = 1;
    5'b00010: amount = 1;
    5'b00011: amount = 2;
    5'b00100: amount = 1;
    5'b00101: amount = 2;
    5'b00110: amount = 2; 
    5'b00111: amount = 3;
    5'b01000: amount = 1;
    5'b01001: amount = 2;
    5'b01010: amount = 2;
    5'b01011: amount = 3;
    5'b01100: amount = 2;
    5'b01101: amount = 3;
    5'b01110: amount = 3;
    5'b01111: amount = 4;
    5'b10000: amount = 1;
    5'b10001: amount = 2;
    5'b10010: amount = 2;
    5'b10011: amount = 3;
    5'b10100: amount = 2;
    5'b10101: amount = 3;
    5'b10110: amount = 3;
    5'b10111: amount = 4;
    5'b11000: amount = 2;
    5'b11001: amount = 3;
    5'b11010: amount = 3;
    5'b11011: amount = 4;
    5'b11100: amount = 3;
    5'b11101: amount = 4;
    5'b11110: amount = 4;
    default: amount = 5;
  endcase
end
  
endmodule

module Laser (
  input              CLK,
  input              RST,
  input      [3:0]     X,
  input      [3:0]     Y,
  input            valid,
  output reg [3:0]   C1X,
  output reg [3:0]   C1Y,
  output reg [3:0]   C2X,
  output reg [3:0]   C2Y,
  output reg        DONE
);

localparam IDLE = 3'd0;
localparam READ = 3'd1;
localparam FIND_INIT = 3'd2;
localparam FIND = 3'd3;
localparam BUFFER = 3'd4;
localparam FINISH = 3'd5;

reg [2:0] currentState, nextState;

reg [7:0] center;
reg [5:0] cnt;
reg [7:0] target [0:39];
reg [4:0] max, globalmax, pre_max, max_temp;
reg [7:0] new_coor;
reg in_current_circle [0:39];
reg in_previous_circle [0:39];
reg temp_list [0:39];
reg [7:0] c1_coor, c2_coor, pre_coor;

wire in_list [0:39];
wire [4:0] T, N, Temp;
wire signed [4:0] dx [0:39], dy [0:39];
wire [3:0] absx [0:39], absy [0:39];
wire [4:0] mask [0:7];
wire [2:0] n [0:7];
wire [2:0] t [0:7];
reg [1:0] counter;

integer i;



always @(posedge CLK or posedge RST) begin
  if (RST) currentState <= IDLE;
  else currentState <= nextState;        
end

always @(*) begin
  case (currentState)
    IDLE: nextState = READ;
    READ: nextState = (cnt == 6'd40)? FIND_INIT : READ;
    FIND_INIT: nextState = FIND;
    FIND: begin
      case (counter)
        0,1: nextState = (center == {4'd11,4'd8})? BUFFER : FIND;
        default: nextState = (center == {4'd11,4'd8} || N + pre_max > globalmax)? BUFFER : FIND;
      endcase
    end
    BUFFER: nextState = (new_coor == c1_coor)? FINISH : FIND_INIT;
    FINISH: nextState = READ;
    default: nextState = IDLE;
  endcase
end

always @(posedge CLK or posedge RST) begin
  if (RST) begin
    C1X <= 0;
    C1Y <= 0;
    C2X <= 0;
    C2Y <= 0;
    DONE <= 0;

    cnt <= 0;
    center <= {4'd2,4'd13};
    max <= 0;
    new_coor <= 0;
    c1_coor <= 0;
    c2_coor <= 0;
    pre_coor <= 0;
    globalmax <= 0;
    pre_max <= 0;
    counter <= 0;
    max_temp <= 0;
    for (i = 0; i < 40; i = i + 1) begin
      target[i] <= 0;
      in_previous_circle[i] <= 0;
      in_current_circle[i] <= 0;
      temp_list[i] <= 0;
    end
  end

  else begin
    case (currentState)
      READ: begin
        DONE <= 0;
        if (valid) begin
          cnt <= cnt + 6'd1;
          target[cnt][3:0] <= X;
          target[cnt][7:4] <= Y;
        end
      end

      FIND_INIT: begin
        center <= center + 8'd1;
        for (i = 0; i < 40; i = i + 1) begin
          temp_list[i] <= in_list[i];
        end

      end

      FIND: begin
        for (i = 0; i < 40; i = i + 1) begin
          temp_list[i] <= in_list[i];
        end
        if (center[3:0] == 4'd12) begin
          center[3:0] <= 4'd2;
          center[7:4] <= center[7:4] + 4'd1;
        end
        else center <= center + 8'd1;

        if (N > max || N == max) begin
          max <= N;
          new_coor <= center - 8'd1;
          max_temp <= T;
          for (i = 0; i < 40; i = i + 1) begin
            in_current_circle[i] <= temp_list[i];
          end
        end
      end

      BUFFER: begin
        center <= {4'd2,4'd13};
        max <= 0;
        counter <= (counter < 2)? counter + 2'd1 : counter;
        
        pre_max <= max_temp;

        pre_coor <= new_coor;
        c1_coor <= pre_coor; 
        c2_coor <= new_coor;
        
        globalmax <= max + pre_max;

        for (i = 0; i < 40; i = i + 1) begin
          in_previous_circle[i] <= in_current_circle[i];
        end
      end

      FINISH: begin
        DONE <= 1'b1;
        C1X <= c1_coor[3:0];
        C1Y <= c1_coor[7:4];
        C2X <= c2_coor[3:0];
        C2Y <= c2_coor[7:4];
        
        cnt <= 0;
        center <= {4'd2,4'd13};
        c1_coor <= 0;
        pre_coor <= 0;
        globalmax <= 0;
        pre_max <= 0;
        counter <= 0;
        for (i = 0; i < 40; i = i + 1) begin
          in_previous_circle[i] <= 0;
        end
      end
    endcase
  end
  
end

genvar k;
generate
  for (k = 0; k < 40; k = k + 1) begin: ckeck_in_current_circle
    assign dx[k] = (target[k][3:0] - center[3:0]);
    assign dy[k] = (target[k][7:4] - center[7:4]);
    assign absx[k] = (dx[k][4])? ~dx[k][3:0] + 4'd1 : dx[k][3:0];
    assign absy[k] = (dy[k][4])? ~dy[k][3:0] + 4'd1 : dy[k][3:0];
    chk_in_circle u0(.abs_x(absx[k]), .abs_y(absy[k]), .in_circle(in_list[k]));
  end
endgenerate

generate
  for (k = 0; k < 8; k = k + 1) begin: count1bits
    countonebits u1(.list({temp_list[0 + 5*k],temp_list[1 + 5*k],temp_list[2 + 5*k],temp_list[3 + 5*k],temp_list[4 + 5*k]}), .mask(5'b11111), .amount(t[k]));
  end
endgenerate

assign T = ((t[0] + t[1]) + (t[2] + t[3])) + ((t[4] + t[5]) + (t[6] + t[7]));

generate
  for (k = 0; k < 8; k = k + 1) begin: count1bits_
    assign mask[k] = ~{in_previous_circle[0 + 5*k], in_previous_circle[1 + 5*k], in_previous_circle[2 + 5*k], in_previous_circle[3 + 5*k], in_previous_circle[4 + 5*k]};
    countonebits u2(.list({temp_list[0 + 5*k],temp_list[1 + 5*k],temp_list[2 + 5*k],temp_list[3 + 5*k],temp_list[4 + 5*k]}), .mask(mask[k]), .amount(n[k]));
  end
endgenerate

assign N = ((n[0] + n[1]) + (n[2] + n[3])) + ((n[4] + n[5]) + (n[6] + n[7]));

endmodule




