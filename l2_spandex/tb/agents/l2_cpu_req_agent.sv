class l2_cpu_req_agent extends uvm_agent;
  //declaring agent components
  l2_cpu_req_driver    driver;
  l2_cpu_req_sequencer sequencer;
  l2_cpu_req_monitor   monitor;

  // UVM automation macros for general components
  `uvm_component_utils(l2_cpu_req_agent)

  // constructor
  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  // build_phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if(get_is_active() == UVM_ACTIVE) begin
      driver = l2_cpu_req_driver::type_id::create("driver", this);
      sequencer = l2_cpu_req_sequencer::type_id::create("sequencer", this);
    end

    monitor = l2_cpu_req_monitor::type_id::create("monitor", this);
  endfunction : build_phase

  // connect_phase
  function void connect_phase(uvm_phase phase);
    if(get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction : connect_phase

endclass : l2_cpu_req_agent