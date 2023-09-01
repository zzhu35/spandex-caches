class l2_cpu_req_test extends uvm_test;

  `uvm_component_utils(l2_cpu_req_test)

  l2_tb_env env;
  l2_cpu_req_sequence  seq;

  function new(string name = "l2_cpu_req_test",uvm_component parent=null);
    super.new(name,parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    env = l2_tb_env::type_id::create("env", this);
    seq = l2_cpu_req_sequence::type_id::create("seq");
  endfunction : build_phase

  task run_phase(uvm_phase phase);
    seq.start(env.l2_cpu_req_agnt.sequencer);
  endtask : run_phase

endclass : l2_cpu_req_test