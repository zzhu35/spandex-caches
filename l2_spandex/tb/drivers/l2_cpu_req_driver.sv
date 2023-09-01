class l2_cpu_req_driver extends uvm_driver #(l2_cpu_req_item);

  // Virtual Interface
  virtual l2_cpu_req_if l2_cpu_req_intf;

  `uvm_component_utils(l2_cpu_req_driver)
    
  // Constructor
  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
     if(!uvm_config_db#(virtual l2_cpu_req_if)::get(this, "", "l2_cpu_req_intf", l2_cpu_req_intf))
       `uvm_fatal("NO_VIF",{"virtual interface must be set for: ",get_full_name(),".l2_cpu_req_intf"});
  endfunction: build_phase

  // run phase
  virtual task run_phase(uvm_phase phase);
    forever begin
    seq_item_port.get_next_item(req);
    drive();
    seq_item_port.item_done();
    end
  endtask : run_phase

  // drive 
  virtual task drive();
    req.print();
  endtask : drive

endclass : l2_cpu_req_driver