class l2_cpu_req_item extends uvm_sequence_item;
    rand cpu_msg_t cpu_msg;
    rand hsize_t hsize;
    rand logic[1:0] hprot;
    rand addr_t addr;
    rand word_t word;
    rand amo_t amo;
    rand logic valid;
    logic ready;
  
    `uvm_object_utils_begin(l2_cpu_req_item)
        `uvm_field_int(cpu_msg, UVM_ALL_ON);
        `uvm_field_int(hsize, UVM_ALL_ON);
        `uvm_field_int(hprot, UVM_ALL_ON);
        `uvm_field_int(addr, UVM_ALL_ON);
        `uvm_field_int(word, UVM_ALL_ON);
        `uvm_field_int(amo, UVM_ALL_ON);
        `uvm_field_int(valid, UVM_ALL_ON);
    `uvm_object_utils_end
  
    function new(string name = "l2_cpu_req_item");
        super.new(name);
    endfunction

endclass : l2_cpu_req_item