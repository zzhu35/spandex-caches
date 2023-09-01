class l2_tb_env extends uvm_env;

  l2_cpu_req_agent l2_cpu_req_agnt;
  
  `uvm_component_utils(l2_tb_env)
    
  // new - constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  // build_phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    l2_cpu_req_agnt = l2_cpu_req_agent::type_id::create("l2_cpu_req_agnt", this);
  endfunction : build_phase

endclass : l2_tb_env