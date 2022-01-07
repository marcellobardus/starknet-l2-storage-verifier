%lang starknet
%builtins pedersen range_check ecdsa bitwise

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_not_zero

from starknet.types import Keccak256Hash, Address, IntsSequence, RLPItem, reconstruct_ints_sequence_list
from starknet.lib.keccak import keccak256
from starknet.lib.trie_proofs import verify_proof
from starknet.lib.bitset import bitset4_get
from starknet.lib.extract_from_rlp import to_list, extract_list_values
from starknet.lib.address import address_words64_to_160bit

# L1HeadersStore simplified interface
@contract_interface
namespace IL1HeadersStore:
    func get_parent_hash(block_number : felt) -> (res : Keccak256Hash):
    end

    func get_state_root(block_number : felt) -> (res : Keccak256Hash):
    end

    func get_transactions_root(block_number : felt) -> (res : Keccak256Hash):
    end

    func get_receipts_root(block_number : felt) -> (res : Keccak256Hash):
    end

    func get_uncles_hash(block_number : felt) -> (res : Keccak256Hash):
    end
end

@storage_var
func _l1_headers_store_addr() -> (res : felt):
end

@storage_var
func _verified_account_storage_hash(account : felt, block : felt) -> (res : Keccak256Hash):
end

@storage_var
func _verified_account_code_hash(account : felt, block : felt) -> (res : Keccak256Hash):
end

@storage_var
func _verified_account_balance(account : felt, block : felt) -> (res : felt):
end

@storage_var
func _verified_account_nonce(account : felt, block : felt) -> (res : felt):
end

# options_set: indicates which element of the decoded proof should be saved in state
# options_set: is a felt in range 0 to 16
# options_set: storage_hash will be saved if 1st bit of the arg is positive
# options_set: code_hash will be saved if 2nd bit of the arg is positive
# options_set: nonce will be saved if 3rd bit of the arg is positive
# options_set: balance will be saved if 4th bit of the arg is positive
@external
func prove_account{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*}(
        options_set : felt, block_number : felt, account : Address, proof_sizes_bytes_len : felt,
        proof_sizes_bytes : felt*, proof_sizes_words_len : felt, proof_sizes_words : felt*,
        proofs_concat_len : felt, proofs_concat : felt*):
    alloc_locals
    let (local account_raw) = alloc()
    assert account_raw[0] = account.word_1
    assert account_raw[1] = account.word_2
    assert account_raw[2] = account.word_3

    let (local keccak_ptr : felt*) = alloc()
    let keccak_ptr_start = keccak_ptr
    let (local path_raw) = keccak256{keccak_ptr=keccak_ptr}(account_raw, 20)

    local path : IntsSequence = IntsSequence(path_raw, 4, 32)

    let (local headers_store_addr) = _l1_headers_store_addr.read()
    let (local state_root_raw : Keccak256Hash) = IL1HeadersStore.get_state_root(
        headers_store_addr, block_number)

    assert_not_zero(state_root_raw.word_1)
    assert_not_zero(state_root_raw.word_2)
    assert_not_zero(state_root_raw.word_3)
    assert_not_zero(state_root_raw.word_4)

    let (local state_root_elements) = alloc()

    assert state_root_elements[0] = state_root_raw.word_1
    assert state_root_elements[1] = state_root_raw.word_2
    assert state_root_elements[2] = state_root_raw.word_3
    assert state_root_elements[3] = state_root_raw.word_4

    local state_root : IntsSequence = IntsSequence(state_root_elements, 4, 32)

    let (local proof : IntsSequence*) = alloc()
    reconstruct_ints_sequence_list(
        proofs_concat,
        proofs_concat_len,
        proof_sizes_words,
        proof_sizes_words_len,
        proof_sizes_bytes,
        proof_sizes_bytes_len,
        proof,
        0,
        0,
        0)

    let (local result : IntsSequence) = verify_proof(path, state_root, proof, proof_sizes_bytes_len)
    let (local result_items : RLPItem*, result_items_len : felt) = to_list(
        result.element, result.element_size_words)
    let (local result_values : IntsSequence*, result_values_len : felt) = extract_list_values(
        result.element, result.element_size_words, result_items, result_items_len)

    let (local address_160) = address_words64_to_160bit(account)

    let (local save_storage_hash) = bitset4_get(options_set, 1)
    if save_storage_hash == 1:
        local storage_hash : Keccak256Hash = Keccak256Hash(
            result_values[2].element[0],
            result_values[2].element[1],
            result_values[2].element[2],
            result_values[2].element[3])
        _verified_account_storage_hash.write(address_160, block_number, storage_hash)
        tempvar syscall_ptr = syscall_ptr
        tempvar range_check_ptr = range_check_ptr
        tempvar pedersen_ptr = pedersen_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar range_check_ptr = range_check_ptr
        tempvar pedersen_ptr = pedersen_ptr
    end

    local syscall_ptr : felt* = syscall_ptr
    local range_check_ptr : felt = range_check_ptr
    local pedersen_ptr : HashBuiltin* = pedersen_ptr

    let (local save_code_hash) = bitset4_get(options_set, 2)
    if save_code_hash == 1:
        local code_hash : Keccak256Hash = Keccak256Hash(
            result_values[3].element[0],
            result_values[3].element[1],
            result_values[3].element[2],
            result_values[3].element[3])
        _verified_account_code_hash.write(address_160, block_number, code_hash)
        tempvar syscall_ptr = syscall_ptr
        tempvar range_check_ptr = range_check_ptr
        tempvar pedersen_ptr = pedersen_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar range_check_ptr = range_check_ptr
        tempvar pedersen_ptr = pedersen_ptr
    end

    local syscall_ptr : felt* = syscall_ptr
    local range_check_ptr : felt = range_check_ptr
    local pedersen_ptr : HashBuiltin* = pedersen_ptr

    let (local save_nonce) = bitset4_get(options_set, 3)
    if save_nonce == 1:
        local nonce = result_values[0].element[0]
        _verified_account_nonce.write(address_160, block_number, nonce)
        tempvar syscall_ptr = syscall_ptr
        tempvar range_check_ptr = range_check_ptr
        tempvar pedersen_ptr = pedersen_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar range_check_ptr = range_check_ptr
        tempvar pedersen_ptr = pedersen_ptr
    end

    local syscall_ptr : felt* = syscall_ptr
    local range_check_ptr : felt = range_check_ptr
    local pedersen_ptr : HashBuiltin* = pedersen_ptr

    let (local save_balance) = bitset4_get(options_set, 4)
    if save_nonce == 1:
        local balance = result_values[1].element[0]
        _verified_account_balance.write(address_160, block_number, balance)
        tempvar syscall_ptr = syscall_ptr
        tempvar range_check_ptr = range_check_ptr
        tempvar pedersen_ptr = pedersen_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar range_check_ptr = range_check_ptr
        tempvar pedersen_ptr = pedersen_ptr
    end

    return ()
end