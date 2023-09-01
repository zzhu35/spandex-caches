class l2_cpu_req_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(l2_cpu_req_scoreboard)
  uvm_analysis_imp#(l2_cpu_req_item, l2_cpu_req_scoreboard) item_collected_export;

  // new - constructor
  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    item_collected_export = new("item_collected_export", this);
  endfunction: build_phase
  
  // write
  virtual function void write(l2_cpu_req_item pkt);
    $display("SCB:: Pkt recived");
    pkt.print();
  endfunction : write

endclass : l2_cpu_req_scoreboard