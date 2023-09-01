class l2_cpu_req_monitor extends uvm_monitor;

  // Virtual Interface
  virtual l2_cpu_req_if l2_cpu_req_intf;

  uvm_analysis_port #(l2_cpu_req_item) item_collected_port;

  // Placeholder to capture transaction information.
  l2_cpu_req_item trans_collected;

  `uvm_component_utils(l2_cpu_req_monitor)

  // new - constructor
  function new (string name, uvm_component parent);
    super.new(name, parent);
    trans_collected = new();
    item_collected_port = new("item_collected_port", this);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual l2_cpu_req_if)::get(this, "", "l2_cpu_req_intf", l2_cpu_req_intf))
       `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".l2_cpu_req_intf"});
  endfunction: build_phase

  // run phase
  virtual task run_phase(uvm_phase phase);
    item_collected_port.write(trans_collected);
  endtask : run_phase

endclass : l2_cpu_req_monitor