class l2_cpu_req_sequencer extends uvm_sequencer#(l2_cpu_req_item);

   `uvm_sequencer_utils(l2_cpu_req_sequencer)
     
  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

endclass : l2_cpu_req_sequencer
