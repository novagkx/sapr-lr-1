module apb_slave
(
    // Входные сигналы APB шины
    input pclk,           // Синхросигнал (тактовый сигнал)
    input presetn,        // Сигнал сброса (активный низкий уровень)
    input [31:0] paddr,   // Адрес обращения (32-битный адрес)
    input [31:0] pwdata,  // Данные для записи (32-битные данные)
    input psel,           // Выбор устройства (активен когда мастер обращается к слейву)
    input penable,        // Признак активной транзакции
    input pwrite,         // Признак операции (1 - запись, 0 - чтение)
    
    // Выходные сигналы APB шины
    output logic pready,  // Признак готовности устройства
    output logic pslverr, // Признак ошибки (опциональный)
    output logic [31:0] prdata // Прочитанные данные
);

// Внутренние регистры устройства
logic [31:0] register_with_some_name;
logic [31:0] group_number_reg;
logic [31:0] date_reg;
logic [31:0] surname_reg;
logic [31:0] name_reg;

initial begin
    group_number_reg = 32'h00000000;
    date_reg         = 32'h00000000;
    surname_reg      = 32'h00000000;
    name_reg         = 32'h00000000;
    pready           = 1'b0;
    pslverr          = 1'b0;
    prdata           = 32'h00000000;
end
// Определение состояний конечного автомата APB
// Используется перечисление (enum) для создания FSM
enum logic [1:0] {
    APB_SETUP,     // Состояние установки
    APB_W_ENABLE,  // Состояние разрешения записи
    APB_R_ENABLE   // Состояние разрешения чтения
} apb_st;

always @(posedge pclk)
if (!presetn)
begin
    // Сброс всех выходных сигналов и регистров
    prdata <= '0;                    // Обнуление данных для чтения
    pslverr <= 1'b0;                 // Сброс сигнала ошибки
    pready <= 1'b0;                  // Сброс готовности
    register_with_some_name <= 32'h0; // Сброс внутреннего регистра
    apb_st <= APB_SETUP;             // Установка начального состояния FSM
end
else
begin
    // Конечный автомат APB протокола
    case(apb_st)
        APB_SETUP:
        begin: apb_setup_st
            // Очистка выходных сигналов
            prdata <= '0;
            pready <= 1'b0;
            pslverr <= 1'b0;
            
            // Переход в состояние ENABLE при выборе устройства
            // Проверка условий: psel=1 и penable=0
            if (psel && !penable)
            begin
                // Выбор следующего состояния в зависимости от операции
                if (pwrite == 1'b1)
                    apb_st <= APB_W_ENABLE; // Запись
                else
                    apb_st <= APB_R_ENABLE; // Чтение
            end
        end

        APB_W_ENABLE:
        begin: apb_w_en_st
            // Проверка условий для операции записи
            if (psel && penable && pwrite)
            begin
                pready <= 1'b1; // Установка готовности
                $display("APB_W_ENABLE: writing addr=0x%h data=0x%h", paddr, pwdata);
                // Декодирование адреса и запись в соответствующий регистр
                case (paddr[7:0]) // Используем младшие 8 бит адреса
                    8'h0: begin
                        // Запись в регистр по смещению 0
                        group_number_reg <= pwdata;
                        $display("[APB_SLAVE] Write to address 0x0: data=0x%h", pwdata);
                    end
                    8'h04: begin
                        date_reg <= pwdata;
                        $display("[APB_SLAVE] Write to address 0x04 (date): data=0x%h", pwdata);
                    end

                    // ---- 0x08: фамилия ----
                    8'h08: begin
                        surname_reg <= pwdata;
                        $display("[APB_SLAVE] Write to address 0x08 (surname): data=0x%h", pwdata);
                    end

                    // ---- 0x0C: имя ----
                    8'h0C: begin
                        name_reg <= pwdata;
                        $display("[APB_SLAVE] Write to address 0x0C (name): data=0x%h", pwdata);
                    end
                    default:
                    begin
                        // Ошибка при обращении к несуществующему адресу
                        pslverr <= 1'b1;
                        $display("[APB_SLAVE] Error: write to invalid address 0x%h", paddr);
                    end
                endcase
                apb_st <= APB_SETUP; // Возврат в исходное состояние
            end
        end

        APB_R_ENABLE:
        begin: apb_r_en_st
            // Проверка условий для операции чтения
            if (psel && penable && !pwrite)
            begin
                pready <= 1'b1; // Установка готовности
                
                // Декодирование адреса и чтение из соответствующего регистра
                case (paddr[7:0])
                    8'h0: begin
                        // Чтение из регистра по смещению 0
                        prdata[31:0] <= group_number_reg[31:0];
                        $display("[APB_SLAVE] Read from address 0x0: data=0x%h", group_number_reg);
                    end
                                // ---- 0x04: дата ----
                    8'h04: begin
                        prdata <= date_reg;
                        $display("[APB_SLAVE] Read from address 0x04 (date): data=0x%h", date_reg);
                    end

                    // ---- 0x08: фамилия ----
                    8'h08: begin
                        prdata <= surname_reg;
                        $display("[APB_SLAVE] Read from address 0x08 (surname): data=0x%h", surname_reg);
                    end

                    // ---- 0x0C: имя ----
                    8'h0C: begin
                        prdata <= name_reg;
                        $display("[APB_SLAVE] Read from address 0x0C (name): data=0x%h", name_reg);
                    end
                    default:
                    begin
                        // Ошибка при обращении к несуществующему адресу
                        pslverr <= 1'b1;
                        $display("[APB_SLAVE] Error: read from invalid address 0x%h", paddr);
                    end
                endcase
                apb_st <= APB_SETUP; // Возврат в исходное состояние
            end
        end

        default:
        begin
            // Обработка недопустимого состояния
            pslverr <= 1'b1;
        end
    endcase
end

endmodule