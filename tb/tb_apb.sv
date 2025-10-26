`timescale 1ns/1ps
module TB;

    logic pclk;
    logic presetn;
    logic psel;
    logic penable;
    logic pwrite;
    logic [31:0] paddr;
    logic [31:0] pwdata;
    wire [31:0] prdata;
    wire pready;
    wire pslverr;

    parameter p_device_offset = 32'h7000_0000;

    // wires for convenience
    logic [31:0] address;
    logic [31:0] data_to_device;
    logic [31:0] data_from_device;

    logic [31:0] my_group_number;
    logic [31:0] my_date_ddmmyyyy;
    logic [31:0] my_surname_4;
    logic [31:0] my_name_4;

    // instantiate DUT
    apb_slave DUT (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(paddr),
        .pwdata(pwdata),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pready(pready),
        .pslverr(pslverr),
        .prdata(prdata)
    );

    // write task
    task automatic apb_write(input logic [31:0] addr, input logic [31:0] data);
        begin
            wait ((penable==0) && (pready == 0));
            @(posedge pclk);
            psel = 1'b1;
            paddr = addr;
            pwdata = data;
            pwrite = 1'b1;
            @(posedge pclk);
            penable = 1'b1;
            @(posedge pclk);
            wait (pready == 1'b1);
            @(posedge pclk);
            psel = 1'b0;
            penable = 1'b0;
            pwrite = 1'b0;
            @(posedge pclk);
        end
    endtask

    // read task
    task automatic apb_read(input logic [31:0] addr, output logic [31:0] data);
    begin
        // Начальное состояние
        psel    = 1'b1;
        pwrite  = 1'b0;
        paddr   = addr;
        penable = 1'b0;

        @(posedge pclk);        // Ждём фронта тактового сигнала
        penable = 1'b1;         // Включаем транзакцию

        // Ждём готовности slave
        wait (pready == 1'b1);
        @(posedge pclk);        // Синхронизация с фронтом

        // Считываем данные
        data = prdata;
        $display("[TB] Read data=0x%h from addr=0x%h at time %0t", data, addr, $time);

        // Завершаем транзакцию
        penable = 1'b0;
        psel    = 1'b0;
        @(posedge pclk);
    end
    endtask

    // clock
    always #10 pclk = ~pclk;

    initial begin
        pclk = 0;
        presetn = 1'b1;
        psel = 1'b0;
        penable = 1'b0;
        pwrite = 1'b0;
        paddr = 32'h0;
        pwdata = 32'h0;

        // reset sequence
        repeat (5) @(posedge pclk);
        presetn = 1'b0;
        repeat (5) @(posedge pclk);
        presetn = 1'b1;
        repeat (5) @(posedge pclk);

        // номер в списке группы:
        my_group_number    = 32'd15;
        my_date_ddmmyyyy   = 32'd26102025;
        // Первые 4 буквы фамилии "NOVI" в ASCII
        my_surname_4 = {8'h4E, 8'h4F, 8'h56, 8'h49}; // "NOVI"
        // Первые 4 буквы имени "ARTY" в ASCII
        my_name_4          = {8'h41, 8'h52, 8'h54, 8'h59}; // "ARTY"

        // Адреса:
        address = p_device_offset + 32'h0;
        // Запись номера в группу
        apb_write(address, my_group_number);
        apb_read(address, data_from_device);
        $display("Addr=0x%h, wrote group number=0x%h, read=0x%h", address, my_group_number, data_from_device);

        // Запись даты
        address = p_device_offset + 32'h4;
        apb_write(address, my_date_ddmmyyyy);
        apb_read(address, data_from_device);
        $display("Addr=0x%h, wrote date(DDMMYYYY)=0x%h, read=0x%h", address, my_date_ddmmyyyy, data_from_device);

        // Запись фамилии (4 ASCII)
        address = p_device_offset + 32'h8;
        apb_write(address, my_surname_4);
        apb_read(address, data_from_device);
        $display("Addr=0x%h, wrote surname4=0x%h, read=0x%h", address, my_surname_4, data_from_device);

        // Запись имени (4 ASCII)
        address = p_device_offset + 32'hC;
        apb_write(address, my_name_4);
        apb_read(address, data_from_device);
        $display("Addr=0x%h, wrote name4=0x%h, read=0x%h", address, my_name_4, data_from_device);

        repeat (10) @(posedge pclk);
        $display("Simulation finished.");
        $stop;
    end

    initial begin
        $monitor("T=%0t PENABLE=%b PREADY=%b PADDR=0x%h PWDATA=0x%h PRDATA=0x%h PSLVERR=%b", $time, penable, pready, paddr, pwdata, prdata, pslverr);
    end

endmodule
