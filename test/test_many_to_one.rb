require 'helper'
require 'json'

class TestManyToOne < Test::Unit::TestCase

  class Puzzle < Remodel::Entity
    has_many :pieces, :class => 'TestManyToOne::Piece', :reverse => 'puzzle'
    property :topic
  end

  class Piece < Remodel::Entity
    has_one :puzzle, :class => 'TestManyToOne::Puzzle'
    property :color
  end

  context "has_many" do
    context "association" do
      should "exist" do
        assert Puzzle.create(context).respond_to?(:pieces)
      end

      should "return an empty list by default" do
        assert_equal [], Puzzle.create(context).pieces
      end
      
      should "return any existing children" do
        puzzle = Puzzle.create(context)
        red_piece = Piece.create(context, :color => 'red')
        blue_piece = Piece.create(context, :color => 'blue')
        value = JSON.generate([red_piece.key, blue_piece.key])
        redis.hset(context.key, "#{puzzle.key}_pieces", value)
        assert_equal 2, puzzle.pieces.size
        assert_equal Piece, puzzle.pieces[0].class
        assert_equal 'red', puzzle.pieces[0].color
      end

      should "not return any child multiple times" do
        puzzle = Puzzle.create(context)
        red_piece = Piece.create(context, :color => 'red')
        value = JSON.generate([red_piece.key, red_piece.key])
        redis.hset(context.key, "#{puzzle.key}_pieces", value)
        assert_equal 1, puzzle.pieces.size
        assert_equal Piece, puzzle.pieces[0].class
        assert_equal 'red', puzzle.pieces[0].color
      end

      context "create" do
        should "have a create method" do
          assert Puzzle.create(context).pieces.respond_to?(:create)
        end

        should "work without attributes" do
          puzzle = Puzzle.create(context)
          piece = puzzle.pieces.create
          assert piece.is_a?(Piece)
        end

        should "create and store a new child" do
          puzzle = Puzzle.create(context)
          puzzle.pieces.create :color => 'green'
          assert_equal 1, puzzle.pieces.size
          puzzle.reload
          assert_equal 1, puzzle.pieces.size
          assert_equal Piece, puzzle.pieces[0].class
          assert_equal 'green', puzzle.pieces[0].color
        end

        should "associate the created child with self" do
          puzzle = Puzzle.create(context, :topic => 'provence')
          piece = puzzle.pieces.create :color => 'green'
          assert_equal 'provence', piece.puzzle.topic
        end
      end

      context "add" do
        should "add the given entity to the association" do
          puzzle = Puzzle.create(context)
          piece = Piece.create(context, :color => 'white')
          puzzle.pieces.add piece
          assert_equal 1, puzzle.pieces.size
          puzzle.reload
          assert_equal 1, puzzle.pieces.size
          assert_equal Piece, puzzle.pieces[0].class
          assert_equal 'white', puzzle.pieces[0].color
        end
      end

      context "find" do
        setup do
          @puzzle = Puzzle.create(context)
          5.times { @puzzle.pieces.create :color => 'blue' }
        end

        should "find the element with the given id" do
          piece = @puzzle.pieces[2]
          assert_equal piece, @puzzle.pieces.find(piece.id)
        end

        should "raise an exception if no element with the given id exists" do
          assert_raises(Remodel::EntityNotFound) { @puzzle.pieces.find(-1) }
        end
      end

    end
  end

  context "reload" do
    should "reset has_many associations" do
      puzzle = Puzzle.create(context)
      piece = puzzle.pieces.create :color => 'black'
      redis.hdel(context.key, "#{puzzle.key}_pieces")
      puzzle.reload
      assert_equal [], puzzle.pieces
    end
  end

end
