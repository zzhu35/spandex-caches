class l2_cpu_req_sequence extends uvm_sequence#(l2_cpu_req_item);
  
  `uvm_object_utils(l2_cpu_req_sequence)
   
  //Constructor
  function new(string name = "l2_cpu_req_sequence");
    super.new(name);
  endfunction
  
  virtual task body();

    req = l2_cpu_req_item::type_id::create("req");
    wait_for_grant();
    assert(req.randomize() with {
      req.addr >= 'h8000_0000;
      req.addr < 'hC000_0000;
    });
    send_request(req);
    wait_for_item_done();

  endtask
  
endclass : l2_cpu_req_sequence
